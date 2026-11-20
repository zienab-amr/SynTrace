using System.Data;
using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.GitHub;

internal sealed class GitHubInstallationReconciler(SynTraceDbContext db, GitHubApiClient github)
{
    public async Task<bool> ReconcileAsync(GitHubConnection connection, CancellationToken ct)
    {
        GitHubInstallation? installation;
        try
        {
            installation = await github.GetInstallationAsync(connection.InstallationId, ct);
        }
        catch (GitHubApiException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            installation = null;
        }

        var removed = installation is null || installation.Id != connection.InstallationId
            || installation.Account.Id != connection.GitHubAccountId;
        var suspended = !removed && installation!.SuspendedAt.HasValue;
        if (!removed && !suspended && !connection.IsSuspended)
            return true;

        var now = DateTime.UtcNow;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        // Restrict the update to the same active tenant/installation. An old poll or delivery cannot
        // reactivate a disconnected installation or modify a replacement with a different ID.
        var changes = await db.Set<GitHubConnection>().IgnoreQueryFilters()
            .Where(c => c.CompanyId == connection.CompanyId && c.InstallationId == connection.InstallationId
                        && c.IsActive && c.UpdatedAt == connection.UpdatedAt)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.IsActive, !removed)
                .SetProperty(c => c.IsSuspended, suspended).SetProperty(c => c.UpdatedAt, now), ct);

        if (changes == 1 && (removed || suspended))
            await db.Set<GitHubRepositoryBinding>().IgnoreQueryFilters()
                .Where(b => b.CompanyId == connection.CompanyId && b.InstallationId == connection.InstallationId && b.IsActive)
                .ExecuteUpdateAsync(s => s.SetProperty(b => b.IsActive, false).SetProperty(b => b.UpdatedAt, now), ct);

        await transaction.CommitAsync(ct);
        return !removed && !suspended;
    }

    public Task<List<GitHubConnection>> GetConnectionsAsync(CancellationToken ct)
        => db.Set<GitHubConnection>().IgnoreQueryFilters().AsNoTracking().Where(c => c.IsActive).ToListAsync(ct);
}

internal sealed class GitHubInstallationReconcileWorker(IServiceScopeFactory scopes, IOptions<GitHubSyncOptions> options,
    ILogger<GitHubInstallationReconcileWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled)
            return;
        using var timer = new PeriodicTimer(TimeSpan.FromHours(options.Value.ReconcileHours));
        do
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                var reconciler = scope.ServiceProvider.GetRequiredService<GitHubInstallationReconciler>();
                foreach (var connection in await reconciler.GetConnectionsAsync(stoppingToken))
                {
                    try { await reconciler.ReconcileAsync(connection, stoppingToken); }
                    catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { throw; }
                    catch (Exception ex)
                    {
                        logger.LogWarning("GitHub installation {InstallationId} could not be checked ({ErrorType}).",
                            connection.InstallationId, ex.GetType().Name);
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogWarning("GitHub installation reconciliation failed ({ErrorType}).", ex.GetType().Name); }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
