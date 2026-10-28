namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraIssueTypePayload
{
    public string IssueTypeId { get; init; } = string.Empty;
    public string? Name { get; init; }
    public string? Description { get; init; }
    public bool? IsSubtask { get; init; }
}
