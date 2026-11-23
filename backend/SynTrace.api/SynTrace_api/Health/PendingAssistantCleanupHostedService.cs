using Microsoft.EntityFrameworkCore;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Health;

/// <summary>
/// A canceled browser connection intentionally leaves the root pending for a follow-up.
/// Reconcile abandoned turns after a generous TTL so history never shows "pending" forever.
/// Does not store unanswered question text in logs.
/// </summary>
public sealed class PendingAssistantCleanupHostedService(
    IServiceScopeFactory scopes, ILogger<PendingAssistantCleanupHostedService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(5));
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                try
                {
                    await using var scope = scopes.CreateAsyncScope();
                    var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
                    // Background jobs have no JWT; limit updates strictly to stale pending rows.
                    var cutoff = DateTime.UtcNow.AddMinutes(-15);
                    var count = await db.ConversationMessages
                        .Where(m => m.Status == "pending" && m.CreatedAt < cutoff)
                        .ExecuteUpdateAsync(updates => updates.SetProperty(m => m.Status, "failed"), stoppingToken);
                    if (count > 0) logger.LogInformation("Expired {Count} abandoned assistant turns.", count);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
                catch (Exception ex)
                {
                    logger.LogWarning("Pending assistant cleanup failed: {ErrorType}", ex.GetType().Name);
                }
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { }
    }
}
