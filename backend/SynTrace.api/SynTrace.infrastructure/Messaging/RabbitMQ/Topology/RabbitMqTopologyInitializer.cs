using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Extensions.Options;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Topology
{
    public class RabbitMqTopologyInitializer
    {
        private readonly RabbitMqConnectionProvider _connectionProvider;
        private readonly IOptions<RabbitMqTopologyOptions> _topologyOptions;

        public RabbitMqTopologyInitializer(
            RabbitMqConnectionProvider connectionProvider,
            IOptions<RabbitMqTopologyOptions> topologyOptions
            )
        {
            _connectionProvider = connectionProvider;
            _topologyOptions = topologyOptions;
        }

        public async Task InitializeAsync(CancellationToken cancellationToken)
        {
            var connection = await _connectionProvider.GetConnectionAsync(cancellationToken);

            await using var channel = await connection.CreateChannelAsync(cancellationToken:cancellationToken);

            var topology = _topologyOptions.Value;

            await channel.ExchangeDeclareAsync(
                exchange: topology.ExchangeName,
                type: topology.ExchangeType,
                durable: true,
                autoDelete: false,
                cancellationToken: cancellationToken
                );

            await channel.QueueDeclareAsync(
                queue: topology.QueueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                cancellationToken: cancellationToken
                );

            await channel.QueueBindAsync(
                queue: topology.QueueName,
                exchange: topology.ExchangeName,
                routingKey: topology.BindingPattern,
                cancellationToken: cancellationToken
                );
        }

    }
}
