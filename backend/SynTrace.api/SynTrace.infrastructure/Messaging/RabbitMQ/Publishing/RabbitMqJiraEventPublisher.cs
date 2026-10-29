using System.Text;
using Microsoft.Extensions.Options;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;
using RabbitMQ.Client;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Publishing
{
    public class RabbitMqJiraEventPublisher
    {
        private readonly RabbitMqConnectionProvider _connectionProvider;
        private readonly IOptions<RabbitMqTopologyOptions> _topologyOptions;

        public RabbitMqJiraEventPublisher(
            RabbitMqConnectionProvider connectionProvider,
            IOptions<RabbitMqTopologyOptions> topologyOptions)
        {
            _connectionProvider = connectionProvider;
            _topologyOptions = topologyOptions;
        }

        public async Task PublishAsync(CancellationToken cancellationToken)
        {
            var connection = await _connectionProvider.GetConnectionAsync(cancellationToken);

            await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);

            var topology = _topologyOptions.Value;

            var message = "Hello";
            var body = Encoding.UTF8.GetBytes(message);

            var properties = new BasicProperties
            {
                ContentType = "text/plain",
                DeliveryMode = (DeliveryModes)2
            };

            await channel.BasicPublishAsync(
                exchange: topology.ExchangeName,
                routingKey: "jira.issue.updated",
                mandatory: true,
                basicProperties: properties,
                body: body,
                cancellationToken: cancellationToken);
        }
    }
}
