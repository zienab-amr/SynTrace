using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace SynTrace.Infrastructure.Integrations.GitHub;

internal sealed class GitHubWebhookDispatcher(IServiceScopeFactory scopes, ILogger<GitHubWebhookDispatcher> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var nextPurge = DateTime.UtcNow;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                var queue = scope.ServiceProvider.GetRequiredService<GitHubWebhookQueue>();
                var dispatched = await queue.DispatchBatchAsync(stoppingToken);
                if (DateTime.UtcNow >= nextPurge)
                {
                    await queue.PurgeSettledAsync(stoppingToken);
                    nextPurge = DateTime.UtcNow.AddHours(1);
                }
                if (dispatched > 0)
                    continue;
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogWarning("GitHub webhook dispatch paused; durable deliveries will retry ({ErrorType}).", ex.GetType().Name);
            }
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }
}
