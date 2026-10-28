namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraUserPayload
{
    public string AccountId { get; init; } = string.Empty;
    public string? DisplayName { get; init; }
    public bool? Active { get; init; }
}
