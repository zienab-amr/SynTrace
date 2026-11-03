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
        await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);
        var topology = _topologyOptions.Value;

        // At most N un-acked messages in flight.
        await channel.BasicQosAsync(0, topology.PrefetchCount, false, cancellationToken);

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += (_, ea) => HandleAsync(channel, ea, topology, cancellationToken);

        await channel.BasicConsumeAsync(topology.QueueName, autoAck: false, consumer: consumer, cancellationToken: cancellationToken);

        _logger.LogInformation("Started consuming Jira events from queue {QueueName}", topology.QueueName);

        await Task.Delay(Timeout.Infinite, cancellationToken);
    }

    private async Task HandleAsync(IChannel channel, BasicDeliverEventArgs ea, RabbitMqTopologyOptions topology, CancellationToken ct)
    {
        CanonicalJiraEvent? message = null;
        try
        {
            message = JsonSerializer.Deserialize<CanonicalJiraEvent>(ea.Body.Span, JiraEventContractJson.Options);
            if (message is null)
                throw new JsonException("The received Jira event was empty.");

            var errors = CanonicalJiraEventValidator.Validate(message);
            if (errors.Count > 0)
            {
                _logger.LogError("Invalid Jira event {EventId}: {Errors}", message.EventId, string.Join("; ", errors));
                await DeadLetterAsync(channel, ea, topology, "validation: " + string.Join("; ", errors), ct);
                return;
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
                message.EventId, message.EventType, ea.RoutingKey, result);

            // ACK only after the DB transaction committed.
            await channel.BasicAckAsync(ea.DeliveryTag, false, ct);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Invalid Jira event JSON (poison message).");
            await DeadLetterAsync(channel, ea, topology, "poison: invalid json", ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // Shutting down: hand the message back untouched.
            await channel.BasicNackAsync(ea.DeliveryTag, false, requeue: true, CancellationToken.None);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process Jira event {EventId}.", message?.EventId);
            await RetryOrDeadLetterAsync(channel, ea, topology, ex.GetType().Name, ct);
        }
    }

    private async Task RetryOrDeadLetterAsync(IChannel channel, BasicDeliverEventArgs ea, RabbitMqTopologyOptions t, string reason, CancellationToken ct)
    {
        var retryCount = GetRetryCount(ea.BasicProperties);

        if (retryCount >= t.MaxRetryCount)
        {
            await DeadLetterAsync(channel, ea, t, $"retries exhausted ({retryCount}): {reason}", ct);
            return;
        }

        var props = CloneProperties(ea.BasicProperties, (RetryHeader, retryCount + 1));
        await channel.BasicPublishAsync(
            exchange: t.RetryExchangeName,
            routingKey: ea.RoutingKey,
            mandatory: false,
            basicProperties: props,
            body: ea.Body,
            cancellationToken: ct);

        // At-least-once: a crash between publish and ack means redelivery; the idempotency ledger absorbs it.
        await channel.BasicAckAsync(ea.DeliveryTag, false, ct);
    }

    private static async Task DeadLetterAsync(IChannel channel, BasicDeliverEventArgs ea, RabbitMqTopologyOptions t, string reason, CancellationToken ct)
    {
        var props = CloneProperties(ea.BasicProperties, ("x-dead-letter-reason", reason));
        await channel.BasicPublishAsync(
            exchange: t.DeadLetterExchangeName,
            routingKey: ea.RoutingKey,
            mandatory: false,
            basicProperties: props,
            body: ea.Body,
            cancellationToken: ct);
        await channel.BasicAckAsync(ea.DeliveryTag, false, ct);
    }

    private static int GetRetryCount(IReadOnlyBasicProperties props)
    {
        if (props.Headers is not null && props.Headers.TryGetValue(RetryHeader, out var value))
        {
            return value switch
            {
                int i => i,
                long l => (int)l,
                short s => s,
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
