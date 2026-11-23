using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.Serialization;
using SynTrace.Contracts.Validation;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Consumers;

public sealed class JiraEventConsumerService
{
    private const string RetryHeader = "x-retry-count";

    private readonly RabbitMqConnectionProvider _connectionProvider;
    private readonly IOptions<RabbitMqTopologyOptions> _topologyOptions;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<JiraEventConsumerService> _logger;

    public JiraEventConsumerService(
        RabbitMqConnectionProvider connectionProvider,
        IOptions<RabbitMqTopologyOptions> topologyOptions,
        IServiceScopeFactory scopeFactory,
        ILogger<JiraEventConsumerService> logger)
    {
        _connectionProvider = connectionProvider;
        _topologyOptions = topologyOptions;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task ConsumeAsync(CancellationToken cancellationToken)
    {
        var connection = await _connectionProvider.GetConnectionAsync(cancellationToken);
        var channelOptions = new CreateChannelOptions(
            publisherConfirmationsEnabled: true, publisherConfirmationTrackingEnabled: true);
        await using var channel = await connection.CreateChannelAsync(channelOptions, cancellationToken);
        var stopped = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        channel.ChannelShutdownAsync += (_, _) =>
        {
            stopped.TrySetResult();
            return Task.CompletedTask;
        };
        var topology = _topologyOptions.Value;

        // At most N un-acked messages in flight.
        await channel.BasicQosAsync(0, topology.PrefetchCount, false, cancellationToken);

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += (_, ea) => HandleAsync(channel, ea, topology, stopped, cancellationToken);
        consumer.UnregisteredAsync += (_, _) =>
        {
            stopped.TrySetResult();
            return Task.CompletedTask;
        };

        await channel.BasicConsumeAsync(topology.QueueName, autoAck: false, consumer: consumer, cancellationToken: cancellationToken);

        _logger.LogInformation("Started consuming Jira events from queue {QueueName}", topology.QueueName);

        await stopped.Task.WaitAsync(cancellationToken);
        throw new InvalidOperationException("The Jira message consumer stopped.");
    }

    private async Task HandleAsync(IChannel channel, BasicDeliverEventArgs delivery, RabbitMqTopologyOptions topology,
        TaskCompletionSource stopped, CancellationToken ct)
    {
        try
        {
            var (reason, poison) = await ProcessDeliveryAsync(delivery, ct);
            if (reason is not null)
                await PublishFailureAsync(channel, delivery, topology, reason, poison, ct);

            // Confirmed, routable failure publication or committed database transaction.
            await channel.BasicAckAsync(delivery.DeliveryTag, false, ct);
        }
        catch (Exception ex)
        {
            if (ex is not OperationCanceledException || !ct.IsCancellationRequested)
            {
                _logger.LogError(ex, "Jira delivery {DeliveryTag} could not be acknowledged. Returning it to the queue.",
                    delivery.DeliveryTag);
            }

            if (!channel.IsOpen)
                return; // Closing the channel returns outstanding deliveries to RabbitMQ.

            try
            {
                using var requeueDeadline = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                if (!ct.IsCancellationRequested)
                    await Task.Delay(TimeSpan.FromSeconds(1), requeueDeadline.Token);
                await channel.BasicNackAsync(delivery.DeliveryTag, false, requeue: true, requeueDeadline.Token);
            }
            catch (Exception dispositionError)
            {
                stopped.TrySetException(dispositionError);
            }
        }
    }

    private async Task<(string? Reason, bool Poison)> ProcessDeliveryAsync(BasicDeliverEventArgs delivery, CancellationToken ct)
    {
        CanonicalJiraEvent? message = null;
        try
        {
            message = JsonSerializer.Deserialize<CanonicalJiraEvent>(delivery.Body.Span, JiraEventContractJson.Options);
            if (message is null)
                throw new JsonException("The received Jira event was empty.");

            var errors = CanonicalJiraEventValidator.Validate(message);
            if (errors.Count > 0)
            {
                var details = string.Join("; ", errors);
                _logger.LogError("Invalid Jira event {EventId}: {Errors}", message.EventId, details);
                return ("validation: " + details, true);
            }

            using var logScope = _logger.BeginScope(new Dictionary<string, object?>
            {
                ["EventId"] = message.EventId,
                ["CorrelationId"] = message.CorrelationId,
                ["TenantId"] = message.CompanyId
            });

            await using var scope = _scopeFactory.CreateAsyncScope();
            var processor = scope.ServiceProvider.GetRequiredService<IJiraEventProcessor>();
            var result = await processor.ProcessAsync(message, ct);

            _logger.LogInformation(
                "Jira event {EventId} ({EventType}, rk {RoutingKey}) -> {Result}",
                message.EventId, message.EventType, delivery.RoutingKey, result);
            return (null, false);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Invalid Jira event JSON or payload.");
            return ("poison: invalid JSON or payload", true);
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            _logger.LogError(ex, "Failed to process Jira event {EventId}.", message?.EventId);
            return (ex.GetType().Name, false);
        }
    }

    private static async Task PublishFailureAsync(IChannel channel, BasicDeliverEventArgs delivery,
        RabbitMqTopologyOptions topology, string reason, bool poison, CancellationToken ct)
    {
        var retryCount = GetRetryCount(delivery.BasicProperties);
        var deadLetter = poison || retryCount >= topology.MaxRetryCount;
        var properties = deadLetter
            ? CloneProperties(delivery.BasicProperties, ("x-dead-letter-reason",
                poison ? reason : $"retries exhausted ({retryCount}): {reason}"))
            : CloneProperties(delivery.BasicProperties, (RetryHeader, retryCount + 1));

        using var publishDeadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
        publishDeadline.CancelAfter(TimeSpan.FromSeconds(10));
        await channel.BasicPublishAsync(
            exchange: deadLetter ? topology.DeadLetterExchangeName : topology.RetryExchangeName,
            routingKey: delivery.RoutingKey,
            mandatory: true,
            basicProperties: properties,
            body: delivery.Body,
            cancellationToken: publishDeadline.Token);
    }

    private static int GetRetryCount(IReadOnlyBasicProperties props)
    {
        if (props.Headers is not null && props.Headers.TryGetValue(RetryHeader, out var value))
        {
            return value switch
            {
                int i => Math.Max(0, i),
                long l => (int)Math.Clamp(l, 0, int.MaxValue),
                short s => Math.Max(0, (int)s),
                byte b => b,
                _ => 0
            };
        }
        return 0;
    }

    private static BasicProperties CloneProperties(IReadOnlyBasicProperties source, params (string Key, object Value)[] extra)
    {
        var headers = new Dictionary<string, object?>();
        if (source.Headers is not null)
            foreach (var kv in source.Headers) headers[kv.Key] = kv.Value;
        foreach (var (key, value) in extra) headers[key] = value;

        return new BasicProperties
        {
            ContentType = source.ContentType,
            DeliveryMode = DeliveryModes.Persistent,
            MessageId = source.MessageId,
            CorrelationId = source.CorrelationId,
            Type = source.Type,
            Headers = headers
        };
    }
}
