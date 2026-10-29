namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;

public sealed class RabbitMqTopologyOptions
{
    public const string SectionName = "RabbitMQ:Topology";

    public string ExchangeName { get; set; } = "syntrace.events";
    public string ExchangeType { get; set; } = "topic";

    public string QueueName { get; set; } = "syntrace.jira.processing";
    public string BindingPattern { get; set; } = "jira.#";
}