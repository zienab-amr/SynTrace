namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class GitHubMessagingOptions
{
    public const string SectionName = "RabbitMQ:GitHub";
    public string Exchange { get; set; } = "syntrace.github.events";
    public string ProcessingQueue { get; set; } = "syntrace.github.processing";
    public string DeadLetterExchange { get; set; } = "syntrace.github.dlx";
    public string DeadLetterQueue { get; set; } = "syntrace.github.dead-letter";
    public string AiQueue { get; set; } = "syntrace.ai.github";
    public ushort Prefetch { get; set; } = 8;
    public int MaxAttempts { get; set; } = 5;
    public int RetryDelaySeconds { get; set; } = 30;
    public int DeliveryRecoveryMinutes { get; set; } = 60;
    public int RetentionDays { get; set; } = 30;
}
