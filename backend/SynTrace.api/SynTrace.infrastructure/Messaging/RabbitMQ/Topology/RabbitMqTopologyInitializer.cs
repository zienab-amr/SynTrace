using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Topology
{
    public class RabbitMqTopologyInitializer
    {
        private const string TopicExchange = "topic";

        private readonly RabbitMqConnectionProvider _connectionProvider;
        private readonly IOptions<RabbitMqTopologyOptions> _topologyOptions;

        public RabbitMqTopologyInitializer(
            RabbitMqConnectionProvider connectionProvider,
            IOptions<RabbitMqTopologyOptions> topologyOptions)
        {
            _connectionProvider = connectionProvider;
            _topologyOptions = topologyOptions;
        }

        public async Task InitializeAsync(CancellationToken cancellationToken)
        {
            var connection = await _connectionProvider.GetConnectionAsync(cancellationToken);
            await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);
            var t = _topologyOptions.Value;

            await channel.ExchangeDeclareAsync(t.ExchangeName, t.ExchangeType, durable: true, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueDeclareAsync(t.QueueName, durable: true, exclusive: false, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueBindAsync(t.QueueName, t.ExchangeName, t.BindingPattern, cancellationToken: cancellationToken);

            await channel.ExchangeDeclareAsync(t.RetryExchangeName, TopicExchange, durable: true, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueDeclareAsync(
                t.RetryQueueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: new Dictionary<string, object?>
                {
                    ["x-message-ttl"] = t.RetryDelaySeconds * 1000,
                    ["x-dead-letter-exchange"] = t.ExchangeName
                },
                cancellationToken: cancellationToken);
            await channel.QueueBindAsync(t.RetryQueueName, t.RetryExchangeName, t.BindingPattern, cancellationToken: cancellationToken);

            await channel.ExchangeDeclareAsync(t.DeadLetterExchangeName, TopicExchange, durable: true, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueDeclareAsync(t.DeadLetterQueueName, durable: true, exclusive: false, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueBindAsync(t.DeadLetterQueueName, t.DeadLetterExchangeName, t.BindingPattern, cancellationToken: cancellationToken);

            await channel.QueueDeclareAsync(t.AiQueueName, durable: true, exclusive: false, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueBindAsync(t.AiQueueName, t.ExchangeName, t.BindingPattern, cancellationToken: cancellationToken);
            await channel.QueueBindAsync(t.AiQueueName, t.ExchangeName, t.AiBindingPattern, cancellationToken: cancellationToken);

            await channel.ExchangeDeclareAsync(t.AiRetryExchangeName, ExchangeType.Direct, durable: true, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueDeclareAsync(
                t.AiRetryQueueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: new Dictionary<string, object?>
                {
                    ["x-message-ttl"] = t.RetryDelaySeconds * 1000,
                    ["x-dead-letter-exchange"] = string.Empty,
                    ["x-dead-letter-routing-key"] = t.AiQueueName
                },
                cancellationToken: cancellationToken);
            await channel.QueueBindAsync(t.AiRetryQueueName, t.AiRetryExchangeName, t.AiRetryRoutingKey, cancellationToken: cancellationToken);

            await channel.ExchangeDeclareAsync(t.AiDeadLetterExchangeName, ExchangeType.Direct, durable: true, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueDeclareAsync(t.AiDeadLetterQueueName, durable: true, exclusive: false, autoDelete: false, cancellationToken: cancellationToken);
            await channel.QueueBindAsync(t.AiDeadLetterQueueName, t.AiDeadLetterExchangeName, t.AiDeadLetterRoutingKey, cancellationToken: cancellationToken);
        }
    }
}
