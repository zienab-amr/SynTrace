namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraProjectPayload
{
    public string ProjectId { get; init; } = string.Empty;
    public string? ProjectKey { get; init; }
    public string? Name { get; init; }
    public string? ProjectTypeKey { get; init; }
    public string? LeadAccountId { get; init; }
}
