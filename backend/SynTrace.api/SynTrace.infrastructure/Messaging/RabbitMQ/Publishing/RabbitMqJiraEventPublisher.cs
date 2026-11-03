using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using SynTrace.Application.Messaging;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.Serialization;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Publishing
{
    public class RabbitMqJiraEventPublisher : IJiraEventPublisher
    {
        private readonly RabbitMqConnectionProvider _connectionProvider;
        private readonly JiraRoutingKeyResolver _routingKeyResolver;
        private readonly IOptions<RabbitMqTopologyOptions> _topologyOptions;

        public RabbitMqJiraEventPublisher(
            RabbitMqConnectionProvider connectionProvider,
            IOptions<RabbitMqTopologyOptions> topologyOptions,
            JiraRoutingKeyResolver routingKeyResolver)
        {
            _connectionProvider = connectionProvider;
            _topologyOptions = topologyOptions;
            _routingKeyResolver = routingKeyResolver;
        }

        public async Task PublishAsync(CanonicalJiraEvent message, CancellationToken cancellationToken)
        {
            ArgumentNullException.ThrowIfNull(message);

            var connection = await _connectionProvider.GetConnectionAsync(cancellationToken);

            await using var channel = await connection.CreateChannelAsync(
                new CreateChannelOptions(
                    publisherConfirmationsEnabled: true,
                    publisherConfirmationTrackingEnabled: true),
                cancellationToken);

            var topology = _topologyOptions.Value;
            var routingKey = _routingKeyResolver.Resolve(message.EventType);

            var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message, JiraEventContractJson.Options));

            var properties = new BasicProperties
            {
                ContentType = "application/json",
                DeliveryMode = DeliveryModes.Persistent,
                MessageId = message.EventId,
                CorrelationId = message.CorrelationId,
                Type = message.EventType.ToString(),
                Timestamp = new AmqpTimestamp(DateTimeOffset.UtcNow.ToUnixTimeSeconds()),
                Headers = new Dictionary<string, object?>
                {
                    ["x-company-id"] = message.CompanyId,
                    ["x-jira-connection-id"] = message.JiraConnectionId,
                    ["x-schema-version"] = message.SchemaVersion
                }
            };

            await channel.BasicPublishAsync(
                exchange: topology.ExchangeName,
                routingKey: routingKey,
                mandatory: true,
                basicProperties: properties,
                body: body,
                cancellationToken: cancellationToken);
        }
    }
}
