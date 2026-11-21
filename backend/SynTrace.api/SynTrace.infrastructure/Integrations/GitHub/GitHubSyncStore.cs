using System.Data;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Persistence.Context;
using Item = SynTrace.Infrastructure.Integrations.GitHub.GitHubSyncSource.SourceItem;

namespace SynTrace.Infrastructure.Integrations.GitHub;

internal sealed class GitHubSyncStore(SynTraceDbContext db, GitHubInstallationReconciler installations) : IGitHubSyncTrigger
{
    private const string RevokedEvent = "github.repository.revoked";

    internal sealed record Work(string BindingId, string Token);
    internal sealed record Job(GitHubRepositoryBinding Binding, GitHubRepositorySync State, GitHubConnection? Connection);

    private DbSet<GitHubRepositoryBinding> Bindings => db.Set<GitHubRepositoryBinding>();
    private DbSet<GitHubConnection> Connections => db.Set<GitHubConnection>();
    private DbSet<GitHubRepositorySync> Sync => db.Set<GitHubRepositorySync>();
    private DbSet<GitHubSyncedItem> Items => db.Set<GitHubSyncedItem>();
    private DbSet<GitHubDataOutbox> Outbox => db.Set<GitHubDataOutbox>();

    public async Task RequestSyncAsync(
        string companyId, long installationId, long? repositoryId, string eventName, string? action, CancellationToken ct)
    {
        if (eventName == "installation")
        {
            var connection = await Connections.IgnoreQueryFilters().AsNoTracking().SingleOrDefaultAsync(c =>
                c.CompanyId == companyId && c.InstallationId == installationId && c.IsActive, ct);
            if (connection is not null)
                await installations.ReconcileAsync(connection, ct);
        }
        var now = DateTime.UtcNow;
        var bindingIds = Bindings.IgnoreQueryFilters()
            .Where(b => b.CompanyId == companyId && b.InstallationId == installationId
                        && (!repositoryId.HasValue || b.RepositoryId == repositoryId.Value))
            .Select(b => b.Id);

        var manual = eventName == "syntrace_mapping" && action == "resync";
        await Sync.Where(x => !x.Revoked && bindingIds.Contains(x.BindingId))
            .ExecuteUpdateAsync(s => s
                .SetProperty(x => x.RequestedVersion, x => x.RequestedVersion + 1)
                .SetProperty(x => x.DueAtUtc, x => manual || x.LastFailure == null ? now : x.DueAtUtc)
                .SetProperty(x => x.LastIndexedHeadSha, x => manual ? null : x.LastIndexedHeadSha)
                .SetProperty(x => x.Phase, x => manual ? "start" : x.Phase)
                .SetProperty(x => x.NextPage, x => manual ? 1 : x.NextPage)
                .SetProperty(x => x.LeaseToken, x => manual ? null : x.LeaseToken)
                .SetProperty(x => x.LeaseUntilUtc, x => manual ? null : x.LeaseUntilUtc), ct);
    }

    public async Task<Work?> ClaimAsync(CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var candidates = await Sync.AsNoTracking().Where(s => !s.Revoked
                && (s.LeaseUntilUtc == null || s.LeaseUntilUtc <= now)
                && (s.DueAtUtc <= now || Bindings.IgnoreQueryFilters().Any(b => b.Id == s.BindingId && !b.IsActive)))
            .OrderBy(x => x.DueAtUtc)
            .ThenBy(x => x.BindingId)
            .Take(10)
            .Select(x => x.BindingId)
            .ToListAsync(ct);

        foreach (var bindingId in candidates)
        {
            var token = Guid.NewGuid().ToString("N");
            var changed = await Sync.Where(x => x.BindingId == bindingId && !x.Revoked
                        && (x.LeaseUntilUtc == null || x.LeaseUntilUtc <= now))
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.LeaseToken, token)
                    .SetProperty(x => x.LeaseUntilUtc, now.AddMinutes(30))
                    .SetProperty(x => x.RequestedVersion, x => x.Phase == "start" && x.RequestedVersion == x.CompletedVersion
                        ? x.RequestedVersion + 1 : x.RequestedVersion), ct);
            if (changed == 1)
                return new Work(bindingId, token);
        }
        return null;
    }

    public async Task<Job?> LoadAsync(Work work, CancellationToken ct)
    {
        var state = await Sync.AsNoTracking().SingleOrDefaultAsync(x => x.BindingId == work.BindingId && x.LeaseToken == work.Token, ct);
        var binding = await Bindings.IgnoreQueryFilters().AsNoTracking().SingleOrDefaultAsync(x => x.Id == work.BindingId, ct);
        if (state is null || binding is null)
            return null;
        var connection = await Connections.IgnoreQueryFilters().AsNoTracking().SingleOrDefaultAsync(
            c => c.CompanyId == binding.CompanyId && c.InstallationId == binding.InstallationId, ct);
        return new Job(binding, state, connection);
    }

    public async Task<Dictionary<string, string?>> GetPullRequestRevisionsAsync(string bindingId, IReadOnlyList<string> ids, CancellationToken ct)
    {
        var rows = await Items.AsNoTracking().Where(x => x.BindingId == bindingId && x.Kind == "pull_request"
                                                       && ids.Contains(x.EntityId)).ToListAsync(ct);
        return rows.ToDictionary(x => x.EntityId, x =>
        {
            using var doc = JsonDocument.Parse(x.PayloadJson);
            return doc.RootElement.String("updatedAt");
        }, StringComparer.Ordinal);
    }

    public async Task<HashSet<string>> GetCommitIdsAsync(string bindingId, IReadOnlyList<string> ids, CancellationToken ct)
        => (await Items.AsNoTracking().Where(x => x.BindingId == bindingId && x.Kind == "commit" && ids.Contains(x.EntityId))
            .Select(x => x.EntityId).ToListAsync(ct)).ToHashSet(StringComparer.Ordinal);

    public async Task<Dictionary<string, string>> GetCodeAsync(string bindingId, CancellationToken ct)
        => await Items.AsNoTracking().Where(x => x.BindingId == bindingId && x.Kind == "file")
            .ToDictionaryAsync(x => x.EntityId, x => x.PayloadJson, ct);

    public async Task ApplyAsync(
        Work work, string phase, int page, string? headSha, IReadOnlyList<Item> payloads,
        int? reconcileHours, GitHubSyncSource.CodeSnapshot? code, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var state = await GetLeaseAsync(work, ct);
        var binding = await Bindings.IgnoreQueryFilters().SingleOrDefaultAsync(b => b.Id == work.BindingId, ct);
        if (state is null || binding is not { IsActive: true } || !await IsConnectionActiveAsync(binding.CompanyId, binding.InstallationId, ct))
            return;

        var now = DateTime.UtcNow;
        if (state.Phase == "start")
        {
            state.RunningVersion = state.RequestedVersion;
            if (payloads.FirstOrDefault(x => x.Kind == "repository") is { } metadata)
            {
                using var document = JsonDocument.Parse(metadata.Json);
                var repository = document.RootElement;
                var owner = repository.String("owner")!;
                var name = repository.String("name")!;
                var branch = repository.String("defaultBranch");
                if (binding.Owner != owner || binding.Name != name || binding.DefaultBranch != branch)
                {
                    binding.Owner = owner;
                    binding.Name = name;
                    binding.FullName = $"{owner}/{name}";
                    binding.DefaultBranch = branch;
                    binding.UpdatedAt = now;
                }
            }
        }
        state.Phase = phase;
        state.NextPage = page;
        state.TargetHeadSha = headSha;
        state.LastFailure = null;
        state.ConsecutiveFailures = 0;

        foreach (var group in payloads.GroupBy(x => x.Kind))
        {
            var values = group.ToList();
            var keys = values.Select(x => x.Id).ToList();
            var existing = code is not null && group.Key == "file"
                ? await Items.Where(x => x.BindingId == binding.Id && x.Kind == group.Key).ToListAsync(ct)
                : await Items.Where(x => x.BindingId == binding.Id && x.Kind == group.Key && keys.Contains(x.EntityId)).ToListAsync(ct);
            var byKey = existing.ToDictionary(x => x.EntityId, StringComparer.Ordinal);
            foreach (var payload in values)
            {
                if (byKey.TryGetValue(payload.Id, out var item) && item.PayloadJson == payload.Json)
                    continue;
                var version = AddOutbox(state, binding, $"github.{payload.Kind}.upserted", payload.Id, payload.Json, now);
                if (item is null)
                {
                    item = new GitHubSyncedItem { BindingId = binding.Id, Kind = payload.Kind, EntityId = payload.Id };
                    Items.Add(item);
                    byKey.Add(payload.Id, item);
                }
                item.PayloadJson = payload.Json;
                item.SourceVersion = version;
                item.UpdatedAtUtc = now;
            }
        }

        if (code is not null)
        {
            var nextFiles = code.Items.Select(x => x.Id).ToHashSet(StringComparer.Ordinal);
            var oldFiles = await Items.Where(x => x.BindingId == binding.Id && x.Kind == "file").ToListAsync(ct);
            foreach (var old in oldFiles.Where(x => !nextFiles.Contains(x.EntityId)))
            {
                AddOutbox(state, binding, "github.file.removed", old.EntityId,
                    JsonSerializer.Serialize(new { headSha }, GitHubSyncSource.JsonOptions), now);
                Items.Remove(old);
            }

            AddOutbox(state, binding, "github.sync.completed", binding.Id,
                JsonSerializer.Serialize(new
                {
                    headSha,
                    preparedFiles = code.Items.Count,
                    skippedFiles = code.SkippedFiles,
                    partialReasons = code.PartialReasons,
                    covers = new[] { "default_branch_commits", "all_pull_requests", "current_default_branch_code" }
                }, GitHubSyncSource.JsonOptions), now);
            state.LastIndexedHeadSha = headSha;
        }

        if (reconcileHours.HasValue)
        {
            state.CompletedVersion = state.RunningVersion;
            state.LastSuccessAtUtc = now;
            state.DueAtUtc = state.RequestedVersion > state.CompletedVersion ? now : now.AddHours(reconcileHours.Value);
        }
        else
            state.DueAtUtc = now;

        ClearLease(state);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
    }

    public async Task RevokeAsync(Work work, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var state = await GetLeaseAsync(work, ct);
        var binding = await Bindings.IgnoreQueryFilters().SingleOrDefaultAsync(b => b.Id == work.BindingId, ct);
        if (state is null || binding is null)
            return;

        await Items.Where(x => x.BindingId == binding.Id).ExecuteDeleteAsync(ct);
        await Outbox.Where(x => x.BindingId == binding.Id).ExecuteDeleteAsync(ct);

        var now = DateTime.UtcNow;
        binding.IsActive = false;
        binding.UpdatedAt = now;
        state.Revoked = true;
        state.Phase = "revoked";
        state.CompletedVersion = state.RequestedVersion;
        state.LastFailure = null;
        ClearLease(state);
        AddOutbox(state, binding, RevokedEvent, binding.Id, "{}", now);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
    }

    public async Task ResetTargetAsync(Work work, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        await Sync.Where(x => x.BindingId == work.BindingId && x.LeaseToken == work.Token)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.Phase, "start")
                .SetProperty(x => x.NextPage, 1)
                .SetProperty(x => x.TargetHeadSha, (string?)null)
                .SetProperty(x => x.LeaseToken, (string?)null).SetProperty(x => x.LeaseUntilUtc, (DateTime?)null)
                .SetProperty(x => x.DueAtUtc, now), ct);
    }

    public async Task DelayAsync(Work work, string error, DateTime? retryAt, CancellationToken ct)
    {
        db.ChangeTracker.Clear();
        var state = await Sync.AsNoTracking().SingleOrDefaultAsync(x => x.BindingId == work.BindingId && x.LeaseToken == work.Token, ct);
        if (state is null)
            return;
        var failures = Math.Min(state.ConsecutiveFailures + 1, 16);
        var now = DateTime.UtcNow;
        var fallback = now.AddSeconds(Math.Min(3600, 15 * Math.Pow(2, failures)));
        var due = retryAt is DateTime date && date > fallback ? date : fallback;
        await Sync.Where(x => x.BindingId == work.BindingId && x.LeaseToken == work.Token)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.LastFailure, error)
                .SetProperty(x => x.ConsecutiveFailures, failures)
                .SetProperty(x => x.DueAtUtc, due)
                .SetProperty(x => x.LeaseToken, (string?)null).SetProperty(x => x.LeaseUntilUtc, (DateTime?)null), ct);
    }

    public Task ReleaseAsync(Work work, CancellationToken ct)
        => Sync.Where(x => x.BindingId == work.BindingId && x.LeaseToken == work.Token)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.LeaseToken, (string?)null)
                .SetProperty(x => x.LeaseUntilUtc, (DateTime?)null), ct);

    public Task<List<GitHubDataOutbox>> PendingAsync(CancellationToken ct)
        => Outbox.AsNoTracking()
            .Where(x => !Outbox.Any(prior => prior.BindingId == x.BindingId && prior.SourceVersion < x.SourceVersion))
            .OrderBy(x => x.OccurredAtUtc).Take(20).ToListAsync(ct);

    public async Task<bool> MayPublishAsync(GitHubDataOutbox row, CancellationToken ct)
    {
        if (row.EventType == RevokedEvent)
            return await Outbox.AnyAsync(x => x.BindingId == row.BindingId && x.SourceVersion == row.SourceVersion, ct);
        return await Outbox.AnyAsync(x => x.BindingId == row.BindingId && x.SourceVersion == row.SourceVersion, ct)
            && await Bindings.IgnoreQueryFilters().AnyAsync(x => x.Id == row.BindingId && x.IsActive, ct)
            && await Sync.AnyAsync(x => x.BindingId == row.BindingId && !x.Revoked, ct)
            && await IsConnectionActiveAsync(row.CompanyId, row.InstallationId, ct);
    }

    public Task AckAsync(GitHubDataOutbox row, CancellationToken ct)
        => Outbox.Where(x => x.BindingId == row.BindingId && x.SourceVersion == row.SourceVersion).ExecuteDeleteAsync(ct);

    private Task<bool> IsConnectionActiveAsync(string company, long installation, CancellationToken ct)
        => Connections.IgnoreQueryFilters().AnyAsync(c => c.CompanyId == company && c.InstallationId == installation && c.IsActive && !c.IsSuspended, ct);

    private Task<GitHubRepositorySync?> GetLeaseAsync(Work work, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        return Sync.SingleOrDefaultAsync(x => x.BindingId == work.BindingId && x.LeaseToken == work.Token
                                             && x.LeaseUntilUtc > now && !x.Revoked, ct);
    }

    private long AddOutbox(GitHubRepositorySync state, GitHubRepositoryBinding binding, string eventType,
        string entityId, string json, DateTime now)
    {
        var version = ++state.ProducedVersion;
        Outbox.Add(new GitHubDataOutbox
        {
            BindingId = binding.Id, SourceVersion = version, CompanyId = binding.CompanyId, ProjectId = binding.ProjectId,
            InstallationId = binding.InstallationId, RepositoryId = binding.RepositoryId,
            EventType = eventType, EntityId = entityId, PayloadJson = json, OccurredAtUtc = now
        });
        return version;
    }

    private static void ClearLease(GitHubRepositorySync state)
    {
        state.LeaseToken = null;
        state.LeaseUntilUtc = null;
    }
}
