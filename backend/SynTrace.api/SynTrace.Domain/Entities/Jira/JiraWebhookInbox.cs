using SynTrace.Domain.Enums.Jira;

namespace SynTrace.Domain.Entities.Jira;

public class JiraWebhookInbox
{
    public string JiraWebhookInboxId { get; set; } = Guid.NewGuid().ToString();

    public string CompanyId { get; set; } = string.Empty;

    public string JiraConnectionId { get; set; } = string.Empty;

    // Identifier from Jira's webhook delivery header.
    public string? DeliveryIdentifier { get; set; }

    // Original event name received from Jira.
    public string RawEventType { get; set; } = string.Empty;

    public long? TimestampUnixMs { get; set; }

    public string RawPayloadJson { get; set; } = string.Empty;

    public DateTimeOffset ReceivedAtUtc { get; set; }

    public JiraWebhookProcessingStatus ProcessingStatus { get; set; }

    public int RetryCount { get; set; }

    public DateTimeOffset? ProcessedAtUtc { get; set; }

    public string? LastError { get; set; }

    public JiraConnection JiraConnection { get; set; } = null!;
}

