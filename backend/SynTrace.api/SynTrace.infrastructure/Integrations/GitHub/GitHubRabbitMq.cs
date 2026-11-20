using System.Text.Json;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Contracts.IntegrationEvents.GitHub;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class GitHubRabbitMq(
    RabbitMqConnectionProvider connections,
    IOptions<GitHubMessagingOptions> options) : IGitHubAiPublisher
{
    internal const string ProcessingRoute = "github.sync.v1";
    internal const string AiRoute = "github.ai.v1";
    internal const string DeadLetterRoute = "github.dead.v1";
    internal static JsonSerializerOptions JsonOptions { get; } = new(JsonSerializerDefaults.Web);
    private readonly GitHubMessagingOptions _options = options.Value;
    private readonly SemaphoreSlim _topologyLock = new(1, 1);
    private IConnection? _declaredOn;

    internal async Task<IConnection> GetConnectionAsync(CancellationToken cancellationToken)
    {
        var connection = await connections.GetConnectionAsync(cancellationToken);
        await _topologyLock.WaitAsync(cancellationToken);
        try
        {
            if (!ReferenceEquals(_declaredOn, connection))
            {
                await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);
                await DeclareAsync(channel, cancellationToken);
                _declaredOn = connection;
            }
        }
        finally
        {
            _topologyLock.Release();
        }
        return connection;
    }

    public Task PublishAsync(GitHubAiEvent message, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(message);
        return PublishAsync(_options.Exchange, AiRoute, message.EventId, message.EventType, message, cancellationToken);
    }

    internal Task PublishDeliveryAsync(Guid deliveryId, CancellationToken cancellationToken) =>
        PublishAsync(_options.Exchange, ProcessingRoute, deliveryId.ToString("D"), "github.delivery", new GitHubDeliveryMessage(deliveryId), cancellationToken);

    internal Task PublishDeadLetterAsync(Guid? deliveryId, string reason, CancellationToken cancellationToken) =>
        PublishAsync(_options.DeadLetterExchange, DeadLetterRoute, deliveryId?.ToString("D") ?? Guid.NewGuid().ToString("D"),
            "github.dead-letter", new GitHubDeadLetterMessage(deliveryId, reason), cancellationToken);

    private async Task PublishAsync<T>(string exchange, string routingKey, string messageId, string messageType, T message,
        CancellationToken cancellationToken)
    {
        var connection = await GetConnectionAsync(cancellationToken);
        await using var channel = await connection.CreateChannelAsync(new CreateChannelOptions(
            publisherConfirmationsEnabled: true, publisherConfirmationTrackingEnabled: true), cancellationToken);
        var properties = new BasicProperties
        {
            ContentType = "application/json",
            DeliveryMode = DeliveryModes.Persistent,
            MessageId = messageId,
            Type = messageType,
            Timestamp = new AmqpTimestamp(DateTimeOffset.UtcNow.ToUnixTimeSeconds())
        };
        await channel.BasicPublishAsync(exchange, routingKey, mandatory: true, properties,
            JsonSerializer.SerializeToUtf8Bytes(message, JsonOptions), cancellationToken);
    }

    private async Task DeclareAsync(IChannel channel, CancellationToken cancellationToken)
    {
        await channel.ExchangeDeclareAsync(_options.Exchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await channel.ExchangeDeclareAsync(_options.DeadLetterExchange, ExchangeType.Topic, durable: true,
            cancellationToken: cancellationToken);
        await DeclareQueueAsync(channel, _options.ProcessingQueue, _options.Exchange, ProcessingRoute, cancellationToken);
        await DeclareQueueAsync(channel, _options.AiQueue, _options.Exchange, AiRoute, cancellationToken);
        await DeclareQueueAsync(channel, _options.DeadLetterQueue, _options.DeadLetterExchange, DeadLetterRoute, cancellationToken);
    }

    private static async Task DeclareQueueAsync(IChannel channel, string name, string exchange, string routingKey,
        CancellationToken cancellationToken)
    {
        await channel.QueueDeclareAsync(name, durable: true, exclusive: false, autoDelete: false,
            cancellationToken: cancellationToken);
        await channel.QueueBindAsync(name, exchange, routingKey, cancellationToken: cancellationToken);
    }
}

internal sealed record GitHubDeliveryMessage(Guid DeliveryId);
internal sealed record GitHubDeadLetterMessage(Guid? DeliveryId, string Reason);
