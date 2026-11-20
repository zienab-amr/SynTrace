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

    // AI side: its own queue, retry and dead-letter, so its failures never reach the Worker.
    public string AiQueueName { get; set; } = "syntrace.ai.jira";
    public string AiBindingPattern { get; set; } = "ai.#";
    public string AiRetryExchangeName { get; set; } = "syntrace.ai.retry";
    public string AiRetryQueueName { get; set; } = "syntrace.ai.jira.retry";
    public string AiRetryRoutingKey { get; set; } = "retry";
    public string AiDeadLetterExchangeName { get; set; } = "syntrace.ai.dlx";
    public string AiDeadLetterQueueName { get; set; } = "syntrace.ai.jira.dead-letter";
    public string AiDeadLetterRoutingKey { get; set; } = "dead";

    public ushort PrefetchCount { get; set; } = 10;
}
