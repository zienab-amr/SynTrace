using System.Text.Json;

namespace SynTrace.Contracts.IntegrationEvents.Jira;

public sealed record CanonicalJiraEvent
{
    public string EventId { get; init; } = string.Empty;

    public JiraEventType EventType { get; init; }

    public int SchemaVersion { get; init; } = 2;

    public string SourceEventName { get; init; } = string.Empty;

    public string CompanyId { get; init; } = string.Empty;

    public string JiraConnectionId { get; init; } = string.Empty;

    /// <summary>Atlassian cloud id of the site. Stable, unlike the site URL.</summary>
    public string CloudId { get; init; } = string.Empty;

    /// <summary>Browser URL of the site, used to build ticket links.</summary>
    public string SiteUrl { get; init; } = string.Empty;

    public string CorrelationId { get; init; } = string.Empty;

    public DateTimeOffset? OccurredAtUtc { get; init; }

    public DateTimeOffset ReceivedAtUtc { get; init; }

    public JsonElement Payload { get; init; }

    /// <summary>The webhook body exactly as Jira sent it. Null for messages that are not webhooks.</summary>
    public JsonElement? RawWebhook { get; init; }
}
