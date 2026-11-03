using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Domain.Enums;
using SynTrace.Domain.Enums.Jira;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

/// <summary>
/// Every few hours: (1) keep dynamic webhooks alive (they expire after 30 days),
/// re-registering if Jira lost them; (2) schedule a re-sync so data that webhooks can't carry (sprints) stays fresh.
/// </summary>
public sealed class JiraMaintenanceHostedService : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromHours(6);
    private static readonly TimeSpan RefreshWhenLessThan = TimeSpan.FromDays(20);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IJiraBackfillQueue _queue;
    private readonly ILogger<JiraMaintenanceHostedService> _logger;

    public JiraMaintenanceHostedService(IServiceScopeFactory scopeFactory, IJiraBackfillQueue queue, ILogger<JiraMaintenanceHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _queue = queue;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try { await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken); }
        catch (OperationCanceledException) { return; }

        using var timer = new PeriodicTimer(Interval);
        do
        {
            try { await RunOnceAsync(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
            catch (Exception ex) { _logger.LogError(ex, "Jira maintenance cycle failed."); }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task RunOnceAsync(CancellationToken ct)
    {
        List<(string Id, long? WebhookId, DateTime? ExpiresAt, JiraSyncStatus Sync)> connections;
        await using (var scope = _scopeFactory.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
            connections = (await db.JiraConnections.AsNoTracking()
                    .Where(c => c.status && c.JiraConnectionType == JiraConnectionType.Company)
                    .Select(c => new { c.Id, c.WebhookId, c.WebhookExpiresAt, c.SyncStatus })
                    .ToListAsync(ct))
                .Select(c => (c.Id, c.WebhookId, c.WebhookExpiresAt, c.SyncStatus))
                .ToList();
        }

        foreach (var c in connections)
        {
            try
            {
                var needsWebhookWork = c.WebhookId is null || c.ExpiresAt is null || c.ExpiresAt < DateTime.UtcNow.Add(RefreshWhenLessThan);
                if (needsWebhookWork)
                {
                    await using var scope = _scopeFactory.CreateAsyncScope();
                    var registration = scope.ServiceProvider.GetRequiredService<IJiraWebhookRegistrationService>();

                    var refreshed = c.WebhookId is not null && await registration.RefreshAsync(c.Id, ct);
                    if (!refreshed)
                    {
                        _logger.LogWarning("Jira webhook for connection {ConnectionId} missing/expired; re-registering.", c.Id);
                        await registration.RegisterAsync(c.Id, ct);
                    }
                }

                if (c.Sync != JiraSyncStatus.Running)
                    await _queue.EnqueueAsync(c.Id, ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Jira maintenance failed for connection {ConnectionId}.", c.Id);
            }
        }
    }
}
