namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;


public sealed record JiraIssueUpdatedPayload
{
    public string IssueId { get; init; } = string.Empty;
    public string IssueKey { get; init; } = string.Empty;
    public string? ProjectId { get; init; }
    public string? ProjectKey { get; init; }
    public string? Summary { get; init; }
    public string? Status { get; init; }
    public string? AssigneeAccountId { get; init; }
    public DateTimeOffset? SourceUpdatedAtUtc { get; init; }
    public IReadOnlyList<JiraFieldChange> Changes { get; init; } = Array.Empty<JiraFieldChange>();
}
