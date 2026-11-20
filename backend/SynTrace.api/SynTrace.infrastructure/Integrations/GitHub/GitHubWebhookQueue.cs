using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.GitHub;

internal sealed class GitHubWebhookQueue(
    SynTraceDbContext db,
    IGitHubSyncTrigger sync,
    GitHubRabbitMq rabbit,
    IOptions<GitHubMessagingOptions> options,
    ILogger<GitHubWebhookQueue> logger)
{
    private readonly GitHubMessagingOptions _options = options.Value;
    private DbSet<GitHubWebhookDelivery> Deliveries => db.Set<GitHubWebhookDelivery>();

    public async Task<int> DispatchBatchAsync(CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var pending = await EligibleForDispatch(now).AsNoTracking()
            .OrderBy(x => x.NextDispatchAtUtc)
            .ThenBy(x => x.ReceivedAtUtc)
            .Select(x => x.Id)
            .Take(32)
            .ToListAsync(ct);

        foreach (var id in pending)
        {
            var lease = Guid.NewGuid();
            var claimedAt = DateTime.UtcNow;
            var claimed = await EligibleForDispatch(claimedAt).Where(x => x.Id == id)
                .ExecuteUpdateAsync(u => u
                    .SetProperty(x => x.DispatchLeaseId, lease)
                    .SetProperty(x => x.DispatchLeaseUntilUtc, claimedAt.AddMinutes(2)), ct);
            if (claimed == 0)
                continue;

            var row = await Deliveries.AsNoTracking().SingleAsync(x => x.Id == id, ct);
            try
            {
                using var publishTimeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                publishTimeout.CancelAfter(TimeSpan.FromSeconds(30));
                if (row.SendToDeadLetter || row.ProcessingAttempts >= _options.MaxAttempts)
                {
                    await rabbit.PublishDeadLetterAsync(id, row.LastFailureType ?? "ProcessingAttemptsExhausted", publishTimeout.Token);
                    await DispatchLease(id, lease).ExecuteUpdateAsync(u => u
                        .SetProperty(x => x.DeadLetteredAtUtc, DateTime.UtcNow)
                        .SetProperty(x => x.DispatchLeaseId, (Guid?)null)
                        .SetProperty(x => x.DispatchLeaseUntilUtc, (DateTime?)null), ct);
                }
                else
                {
                    await rabbit.PublishDeliveryAsync(id, publishTimeout.Token);
                    var publishedAt = DateTime.UtcNow;
                    await DispatchLease(id, lease).ExecuteUpdateAsync(u => u
                        .SetProperty(x => x.LastPublishedAtUtc, publishedAt)
                        .SetProperty(x => x.NextDispatchAtUtc, publishedAt.AddMinutes(_options.DeliveryRecoveryMinutes))
                        .SetProperty(x => x.DispatchLeaseId, (Guid?)null)
                        .SetProperty(x => x.DispatchLeaseUntilUtc, (DateTime?)null), ct);
                }
            }
            catch (Exception ex) when (!ct.IsCancellationRequested)
            {
                logger.LogWarning("GitHub delivery {DeliveryId} publish will retry ({ErrorType}).", id, ex.GetType().Name);
                await DispatchLease(id, lease).ExecuteUpdateAsync(u => u
                    .SetProperty(x => x.NextDispatchAtUtc, DateTime.UtcNow.AddSeconds(_options.RetryDelaySeconds))
                    .SetProperty(x => x.DispatchLeaseId, (Guid?)null)
                    .SetProperty(x => x.DispatchLeaseUntilUtc, (DateTime?)null), ct);
                // An unavailable broker should not trigger 32 consecutive connection timeouts.
                return 0;
            }
        }
        return pending.Count;
    }

    public async Task ProcessAsync(Guid id, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var lease = Guid.NewGuid();
        var claimed = await Deliveries.Where(x => x.Id == id && x.CompletedAtUtc == null && x.DeadLetteredAtUtc == null &&
                !x.SendToDeadLetter && x.ProcessingAttempts < _options.MaxAttempts &&
                (x.ProcessingNotBeforeUtc == null || x.ProcessingNotBeforeUtc <= now) &&
                (x.ProcessingLeaseUntilUtc == null || x.ProcessingLeaseUntilUtc <= now))
            .ExecuteUpdateAsync(u => u
                .SetProperty(x => x.ProcessingLeaseId, lease)
                .SetProperty(x => x.ProcessingLeaseUntilUtc, now.AddMinutes(15))
                .SetProperty(x => x.ProcessingAttempts, x => x.ProcessingAttempts + 1)
                .SetProperty(x => x.NextDispatchAtUtc, now.AddMinutes(15))
                .SetProperty(x => x.DispatchLeaseId, (Guid?)null)
                .SetProperty(x => x.DispatchLeaseUntilUtc, (DateTime?)null), ct);
        // Repeated broker delivery can be acknowledged. Work remains represented in SQL.
        if (claimed == 0)
            return;

        var row = await Deliveries.AsNoTracking().SingleAsync(x => x.Id == id, ct);
        try
        {
            if (await StillInScopeAsync(row, ct))
                await sync.RequestSyncAsync(row.CompanyId, row.InstallationId, row.RepositoryId, row.EventName, row.Action, ct);

            await ProcessingLease(id, lease).ExecuteUpdateAsync(u => u
                .SetProperty(x => x.CompletedAtUtc, DateTime.UtcNow)
                .SetProperty(x => x.ProcessingLeaseId, (Guid?)null)
                .SetProperty(x => x.ProcessingLeaseUntilUtc, (DateTime?)null), ct);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            var exhausted = row.ProcessingAttempts >= _options.MaxAttempts;
            var failure = ex.GetType().Name;
            if (failure.Length > 80) failure = failure[..80];
            var retryAt = exhausted ? DateTime.UtcNow : DateTime.UtcNow.AddSeconds(RetryDelaySeconds(row.ProcessingAttempts));
            await ProcessingLease(id, lease).ExecuteUpdateAsync(u => u
                .SetProperty(x => x.NextDispatchAtUtc, retryAt)
                .SetProperty(x => x.ProcessingNotBeforeUtc, retryAt)
                .SetProperty(x => x.LastFailureType, failure)
                .SetProperty(x => x.SendToDeadLetter, exhausted)
                .SetProperty(x => x.ProcessingLeaseId, (Guid?)null)
                .SetProperty(x => x.ProcessingLeaseUntilUtc, (DateTime?)null), ct);
            logger.LogWarning("GitHub webhook {DeliveryId} failed on attempt {Attempt} ({ErrorType}). Final failure: {Exhausted}.",
                id, row.ProcessingAttempts, failure, exhausted);
        }
    }

    public async Task PurgeSettledAsync(CancellationToken ct)
    {
        var before = DateTime.UtcNow.AddDays(-_options.RetentionDays);
        var expiredIds = await Deliveries.AsNoTracking()
            .Where(x => x.CompletedAtUtc < before || x.DeadLetteredAtUtc < before)
            .OrderBy(x => x.ReceivedAtUtc).Select(x => x.Id)
            .Take(500).ToListAsync(ct);
        if (expiredIds.Count > 0)
            await Deliveries.Where(x => expiredIds.Contains(x.Id)).ExecuteDeleteAsync(ct);
    }

    private IQueryable<GitHubWebhookDelivery> EligibleForDispatch(DateTime now) => Deliveries.Where(x =>
        x.CompletedAtUtc == null && x.DeadLetteredAtUtc == null && x.NextDispatchAtUtc <= now &&
        (x.ProcessingLeaseUntilUtc == null || x.ProcessingLeaseUntilUtc <= now) &&
        (x.DispatchLeaseUntilUtc == null || x.DispatchLeaseUntilUtc <= now));

    private IQueryable<GitHubWebhookDelivery> DispatchLease(Guid id, Guid lease) =>
        Deliveries.Where(x => x.Id == id && x.DispatchLeaseId == lease);

    private IQueryable<GitHubWebhookDelivery> ProcessingLease(Guid id, Guid lease) =>
        Deliveries.Where(x => x.Id == id && x.ProcessingLeaseId == lease);

    private async Task<bool> StillInScopeAsync(GitHubWebhookDelivery row, CancellationToken ct)
    {
        var lifecycle = row.EventName is "installation" or "installation_repositories";
        var parent = await db.Set<GitHubConnection>().AsNoTracking().AnyAsync(x => x.CompanyId == row.CompanyId &&
            x.InstallationId == row.InstallationId && x.IsActive && (lifecycle || !x.IsSuspended), ct);
        if (!parent)
            return false;
        if (row.RepositoryId is null)
            return lifecycle;
        return await db.Set<GitHubRepositoryBinding>().AsNoTracking().AnyAsync(x => x.CompanyId == row.CompanyId &&
            x.InstallationId == row.InstallationId && x.RepositoryId == row.RepositoryId && x.Id == row.BindingId && x.IsActive, ct);
    }

    private int RetryDelaySeconds(int attempt) =>
        Math.Min(1800, _options.RetryDelaySeconds * (1 << Math.Clamp(attempt - 1, 0, 5)));
}
