namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraWorklogPayload
{
    public string WorklogId { get; init; } = string.Empty;
    public string IssueId { get; init; } = string.Empty;
    public string? IssueKey { get; init; }
    public string? AuthorAccountId { get; init; }
    public long? TimeSpentSeconds { get; init; }
    public DateTimeOffset? StartedAtUtc { get; init; }
}
