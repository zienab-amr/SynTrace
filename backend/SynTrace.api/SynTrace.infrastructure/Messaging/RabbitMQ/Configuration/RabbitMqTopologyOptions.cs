namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;

public sealed class RabbitMqTopologyOptions
{
    public const string SectionName = "RabbitMQ:Topology";

    public string ExchangeName { get; set; } = "syntrace.events";
    public string ExchangeType { get; set; } = "topic";

    public string QueueName { get; set; } = "syntrace.jira.processing";
    public string BindingPattern { get; set; } = "jira.#";

    public string RetryExchangeName { get; set; } = "syntrace.events.retry";
    public string RetryQueueName { get; set; } = "syntrace.jira.retry";
    public int RetryDelaySeconds { get; set; } = 30;
    public int MaxRetryCount { get; set; } = 5;

    public string DeadLetterExchangeName { get; set; } = "syntrace.events.dlx";
    public string DeadLetterQueueName { get; set; } = "syntrace.jira.dead-letter";

    public ushort PrefetchCount { get; set; } = 10;
}
