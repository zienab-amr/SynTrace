using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Consumers;

namespace SynTrace.Worker;

public sealed class Worker(
    JiraEventConsumerService consumerService,
    ILogger<Worker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("SynTrace RabbitMQ Worker starting.");

        // If the broker/DB is down at startup or the connection drops, restart the consumer instead of crashing the host.
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await consumerService.ConsumeAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Jira consumer stopped unexpectedly. Restarting in 10 seconds.");
                try { await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken); }
                catch (OperationCanceledException) { break; }
            }
        }
    }
}
