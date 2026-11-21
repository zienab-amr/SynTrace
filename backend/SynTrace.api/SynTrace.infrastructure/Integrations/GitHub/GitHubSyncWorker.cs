using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Contracts.IntegrationEvents.GitHub;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public static class GitHubSyncRegistration
{
    public static IServiceCollection AddGitHubSync(this IServiceCollection services, IConfiguration configuration, bool runWorker)
    {
        services.AddOptions<GitHubSyncOptions>().Bind(configuration.GetSection(GitHubSyncOptions.SectionName))
            .Validate(x => x.ReconcileHours is >= 1 and <= 168 && x.MaxCodeFileBytes is >= 1 and <= 262_144
                && x.MaxCodeFiles is >= 1 and <= 2_000 && x.MaxCodeSnapshotBytes is >= 1 and <= 33_554_432
                && x.MaxTreeEntries is >= 1_000 and <= 1_000_000, "GitHub sync limits are outside supported bounds.")
            .ValidateOnStart();
        services.AddScoped<GitHubInstallationReconciler>();
        services.AddScoped<GitHubSyncStore>();
        services.AddScoped<IGitHubSyncTrigger>(sp => sp.GetRequiredService<GitHubSyncStore>());
        if (runWorker)
        {
            services.AddScoped<GitHubSyncSource>();
            services.AddScoped<GitHubSyncWorkStep>();
            services.AddHostedService<GitHubSyncWorker>();
            services.AddHostedService<GitHubInstallationReconcileWorker>();
            services.AddHostedService<GitHubDataOutboxWorker>();
        }
        return services;
    }
}

internal sealed class GitHubSyncWorkStep(GitHubSyncStore store, GitHubSyncSource source, GitHubInstallationReconciler installations,
    IOptions<GitHubSyncOptions> options, ILogger<GitHubSyncWorkStep> logger)
{
    public async Task<bool> RunAsync(CancellationToken ct)
    {
        var work = await store.ClaimAsync(ct);
        if (work is null)
            return false;

        try
        {
            var job = await store.LoadAsync(work, ct);
            if (job is null)
                return false;
            if (!job.Binding.IsActive || job.Connection is not { IsActive: true })
            {
                await store.RevokeAsync(work, ct);
                return true;
            }
            if (!await installations.ReconcileAsync(job.Connection, ct))
            {
                await store.RevokeAsync(work, ct);
                return true;
            }
            var repository = await source.OpenAsync(job.Binding, ct);
            if (repository is null)
            {
                await store.RevokeAsync(work, ct);
                return true;
            }

            await ProcessAsync(work, job, repository, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (GitHubApiException ex)
        {
            var code = ex.StatusCode is null ? "Unavailable" : ((int)ex.StatusCode.Value).ToString();
            logger.LogWarning("GitHub returned status {HttpStatus} for binding {BindingId}.", code, work.BindingId);
            await store.DelayAsync(work, $"GitHub API status: {code}.", ex.RetryAtUtc, ct);
        }
        catch (Exception ex)
        {
            logger.LogWarning("GitHub synchronization failed for binding {BindingId} ({ErrorType}).", work.BindingId, ex.GetType().Name);
            await store.DelayAsync(work, "GitHub synchronization failed. Retry or check the worker logs.", null, ct);
        }
        finally
        {
            // Clear our claim after orderly shutdown. Other workers may reclaim after the lease expires.
            using var releaseTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            try { await store.ReleaseAsync(work, releaseTimeout.Token); }
            catch (Exception ex)
            {
                logger.LogWarning("Could not release GitHub sync lease for binding {BindingId} ({ErrorType}).", work.BindingId, ex.GetType().Name);
            }
        }
        return true;
    }

    private async Task ProcessAsync(GitHubSyncStore.Work work, GitHubSyncStore.Job job, GitHubSyncSource.Repository repo, CancellationToken ct)
    {
        var state = job.State;
        switch (state.Phase)
        {
            case "start":
                var record = GitHubSyncSource.SourceItem.Create("repository", repo.Id.ToString(), new
                {
                    id = repo.Id, owner = repo.Owner, name = repo.Name, fullName = $"{repo.Owner}/{repo.Name}",
                    defaultBranch = repo.DefaultBranch, headSha = repo.HeadSha, isPrivate = repo.IsPrivate, url = repo.Web
                });
                // Await checkpoint before starting historical reads so a crash can resume the pinned history.
                var phase = repo.HeadSha is not null && repo.HeadSha != state.LastIndexedHeadSha ? "commits" : "pull_requests";
                await store.ApplyAsync(work, phase, 1, repo.HeadSha, [record], null, null, ct);
                break;

            case "commits":
                GitHubSyncSource.SourcePage commits;
                try
                {
                    commits = await source.ReadCommitPageAsync(repo, state.TargetHeadSha!, state.LastIndexedHeadSha, state.NextPage,
                        (keys, token) => store.GetCommitIdsAsync(work.BindingId, keys, token), ct);
                }
                catch (GitHubApiException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound && repo.HeadSha != state.TargetHeadSha)
                {
                    // A force push can make a pinned old head inaccessible.
                    await store.ResetTargetAsync(work, ct);
                    return;
                }
                await store.ApplyAsync(work, commits.HasNextPage ? "commits" : "pull_requests",
                    commits.HasNextPage ? state.NextPage + 1 : 1, state.TargetHeadSha, commits.Items, null, null, ct);
                break;

            case "pull_requests":
                var prs = await source.ReadPullRequestPageAsync(repo, state.NextPage,
                    (keys, token) => store.GetPullRequestRevisionsAsync(work.BindingId, keys, token), ct);
                await store.ApplyAsync(work, prs.HasNextPage ? "pull_requests" : "code",
                    prs.HasNextPage ? state.NextPage + 1 : 1, state.TargetHeadSha, prs.Items, null, null, ct);
                break;

            case "code":
                if (repo.HeadSha != state.TargetHeadSha)
                {
                    await store.ResetTargetAsync(work, ct);
                    return;
                }

                if (repo.HeadSha == state.LastIndexedHeadSha && state.LastSuccessAtUtc.HasValue)
                {
                    await store.ApplyAsync(work, "start", 1, repo.HeadSha, [], options.Value.ReconcileHours, null, ct);
                    return;
                }

                var previous = await store.GetCodeAsync(work.BindingId, ct);
                var snapshot = await source.ReadCodeSnapshotAsync(repo, previous, ct);
                var current = await source.OpenAsync(job.Binding, ct);
                if (current is null)
                {
                    await store.RevokeAsync(work, ct);
                    return;
                }
                if (current.HeadSha != repo.HeadSha)
                {
                    await store.ResetTargetAsync(work, ct);
                    return;
                }
                await store.ApplyAsync(work, "start", 1, repo.HeadSha, snapshot.Items, options.Value.ReconcileHours, snapshot, ct);
                break;

            default:
                throw new InvalidDataException("Unknown GitHub sync phase.");
        }
    }
}

internal sealed class GitHubSyncWorker(IServiceScopeFactory scopes, IOptions<GitHubSyncOptions> options,
    ILogger<GitHubSyncWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled)
            return;

        while (!stoppingToken.IsCancellationRequested)
        {
            var work = false;
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                work = await scope.ServiceProvider.GetRequiredService<GitHubSyncWorkStep>().RunAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogWarning("GitHub sync scheduler could not run ({ErrorType}).", ex.GetType().Name); }
            if (!work)
                await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
        }
    }
}

internal sealed class GitHubDataOutboxWorker(IServiceScopeFactory scopes, IOptions<GitHubSyncOptions> options,
    ILogger<GitHubDataOutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled)
            return;

        while (!stoppingToken.IsCancellationRequested)
        {
            var progressed = false;
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                var store = scope.ServiceProvider.GetRequiredService<GitHubSyncStore>();
                var publisher = scope.ServiceProvider.GetRequiredService<IGitHubAiPublisher>();
                foreach (var row in await store.PendingAsync(stoppingToken))
                {
                    try
                    {
                        if (await store.MayPublishAsync(row, stoppingToken))
                        {
                            using var payload = JsonDocument.Parse(row.PayloadJson);
                            using var limit = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                            limit.CancelAfter(TimeSpan.FromSeconds(12));
                            await publisher.PublishAsync(new GitHubAiEvent($"{row.BindingId}:{row.SourceVersion}", row.EventType,
                                row.CompanyId, row.ProjectId, row.BindingId, row.InstallationId, row.RepositoryId, row.EntityId,
                                row.SourceVersion, row.OccurredAtUtc, payload.RootElement.Clone()), limit.Token);
                        }
                        await store.AckAsync(row, stoppingToken);
                        progressed = true;
                    }
                    catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { throw; }
                    catch (Exception ex)
                    {
                        logger.LogWarning("GitHub AI outbox event {BindingId}/{SourceVersion} will retry ({ErrorType}).",
                            row.BindingId, row.SourceVersion, ex.GetType().Name);
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogWarning("GitHub AI outbox could not run ({ErrorType}).", ex.GetType().Name); }

            if (!progressed)
                await Task.Delay(TimeSpan.FromSeconds(4), stoppingToken);
        }
    }
}
