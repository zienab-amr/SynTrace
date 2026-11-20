using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace SynTrace.Infrastructure.Integrations.GitHub;

internal sealed class GitHubWebhookConsumer(
    GitHubRabbitMq rabbit,
    IServiceScopeFactory scopes,
    IOptions<GitHubMessagingOptions> options,
    ILogger<GitHubWebhookConsumer> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var connection = await rabbit.GetConnectionAsync(stoppingToken);
                await using var channel = await connection.CreateChannelAsync(cancellationToken: stoppingToken);
                var closed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
                channel.ChannelShutdownAsync += (_, _) =>
                {
                    closed.TrySetResult();
                    return Task.CompletedTask;
                };
                var settings = options.Value;
                await channel.BasicQosAsync(0, settings.Prefetch, false, stoppingToken);
                var consumer = new AsyncEventingBasicConsumer(channel);
                consumer.ReceivedAsync += (_, delivery) => HandleAsync(channel, delivery, stoppingToken);
                consumer.UnregisteredAsync += (_, _) =>
                {
                    closed.TrySetResult();
                    return Task.CompletedTask;
                };
                await channel.BasicConsumeAsync(settings.ProcessingQueue, autoAck: false, consumer: consumer,
                    cancellationToken: stoppingToken);
                logger.LogInformation("Consuming GitHub webhook deliveries from {Queue}.", settings.ProcessingQueue);
                await closed.Task.WaitAsync(stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                logger.LogWarning("GitHub webhook consumer will reconnect ({ErrorType}).", ex.GetType().Name);
            }
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }

    private async Task HandleAsync(IChannel channel, BasicDeliverEventArgs delivery, CancellationToken ct)
    {
        try
        {
            var message = Parse(delivery.Body);
            if (message is null)
            {
                // Do not forward untrusted broker content to the dead-letter queue.
                await rabbit.PublishDeadLetterAsync(null, "InvalidDeliveryEnvelope", ct);
            }
            else
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<GitHubWebhookQueue>().ProcessAsync(message.DeliveryId, ct);
            }
            await channel.BasicAckAsync(delivery.DeliveryTag, multiple: false, cancellationToken: ct);
        }
        catch (Exception ex)
        {
            if (ct.IsCancellationRequested || !channel.IsOpen)
                return; // Closing a channel returns any unacknowledged messages to the queue.
            logger.LogWarning("GitHub RabbitMQ delivery will be retried ({ErrorType}).", ex.GetType().Name);
            await Task.Delay(TimeSpan.FromSeconds(2), ct);
            await channel.BasicNackAsync(delivery.DeliveryTag, multiple: false, requeue: true, cancellationToken: ct);
        }
    }

    private static GitHubDeliveryMessage? Parse(ReadOnlyMemory<byte> body)
    {
        if (body.Length is 0 or > 1024)
            return null;
        try
        {
            var message = JsonSerializer.Deserialize<GitHubDeliveryMessage>(body.Span, GitHubRabbitMq.JsonOptions);
            return message is not null && message.DeliveryId != Guid.Empty ? message : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
