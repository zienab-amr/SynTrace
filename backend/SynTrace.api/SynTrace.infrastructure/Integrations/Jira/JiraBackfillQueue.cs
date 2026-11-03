using System.Collections.Concurrent;
using System.Threading.Channels;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Integrations.Jira;

namespace SynTrace.Infrastructure.Integrations.Jira;

/// <summary>In-process queue so the HTTP request that triggers a sync returns immediately.</summary>
public sealed class JiraBackfillQueue : IJiraBackfillQueue
{
    private readonly Channel<string> _channel = Channel.CreateUnbounded<string>();
    private readonly ConcurrentDictionary<string, byte> _pending = new();

    public ChannelReader<string> Reader => _channel.Reader;

    public ValueTask EnqueueAsync(string connectionId, CancellationToken cancellationToken = default) =>
        _pending.TryAdd(connectionId, 0)                       // already queued/running => ignore (no duplicate runs)
            ? _channel.Writer.WriteAsync(connectionId, cancellationToken)
            : ValueTask.CompletedTask;

    public void MarkFinished(string connectionId) => _pending.TryRemove(connectionId, out _);
}

public sealed class JiraBackfillHostedService : BackgroundService
{
    private readonly JiraBackfillQueue _queue;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<JiraBackfillHostedService> _logger;

    public JiraBackfillHostedService(JiraBackfillQueue queue, IServiceScopeFactory scopeFactory, ILogger<JiraBackfillHostedService> logger)
    {
        _queue = queue;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var connectionId in _queue.Reader.ReadAllAsync(stoppingToken))
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var service = scope.ServiceProvider.GetRequiredService<IJiraBackfillService>();
                await service.RunAsync(connectionId, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled error in Jira back-fill for {ConnectionId}.", connectionId);
            }
            finally
            {
                _queue.MarkFinished(connectionId);
            }
        }
    }
}
