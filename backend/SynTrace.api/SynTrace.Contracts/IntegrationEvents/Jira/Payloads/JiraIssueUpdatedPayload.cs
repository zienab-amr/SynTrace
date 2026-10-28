namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

/// <summary>Normalized issue-update payload with field changes, when Jira provides them.</summary>
public sealed record JiraIssueUpdatedPayload
{
    public string IssueId { get; init; } = string.Empty;
    public string IssueKey { get; init; } = string.Empty;
    public string? ProjectId { get; init; }
    public string? ProjectKey { get; init; }
    public string? Summary { get; init; }
    public IReadOnlyList<JiraFieldChange> Changes { get; init; } = Array.Empty<JiraFieldChange>();
}
