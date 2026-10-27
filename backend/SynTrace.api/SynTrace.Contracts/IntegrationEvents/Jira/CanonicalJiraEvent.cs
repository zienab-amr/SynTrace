using System.Text.Json;

namespace SynTrace.Contracts.IntegrationEvents.Jira;

public sealed record CanonicalJiraEvent
{
    public string EventId { get; init; } = string.Empty;

    public JiraEventType EventType { get; init; }

    public int SchemaVersion { get; init; } = 1;

    public string SourceEventName { get; init; } = string.Empty;

    public string CompanyId { get; init; } = string.Empty;

    public string JiraConnectionId { get; init; } = string.Empty;

    public DateTimeOffset? OccurredAtUtc { get; init; }

    public DateTimeOffset ReceivedAtUtc { get; init; }

    public JsonElement Payload { get; init; }
}