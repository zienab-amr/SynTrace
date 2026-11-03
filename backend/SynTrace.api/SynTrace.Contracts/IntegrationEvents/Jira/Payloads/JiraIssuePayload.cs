namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

/// <summary>Normalized issue fields needed by downstream SynTrace processing.</summary>
public sealed record JiraIssuePayload
{
    public string IssueId { get; init; } = string.Empty;
    public string IssueKey { get; init; } = string.Empty;
    public string? ProjectId { get; init; }
    public string? ProjectKey { get; init; }
    public string? Summary { get; init; }
    public string? Status { get; init; }
    public string? AssigneeAccountId { get; init; }
    public DateTimeOffset? SourceUpdatedAtUtc { get; init; }
    /// <summary>Jira ids of the issue's subtasks. Used to delete them with their parent.</summary>
    public IReadOnlyList<string> SubtaskIds { get; init; } = Array.Empty<string>();
}
