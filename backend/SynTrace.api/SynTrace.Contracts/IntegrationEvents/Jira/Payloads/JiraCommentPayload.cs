namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraCommentPayload
{
    public string CommentId { get; init; } = string.Empty;
    public string IssueId { get; init; } = string.Empty;
    public string? IssueKey { get; init; }
    public string? AuthorAccountId { get; init; }
    public string? BodyText { get; init; }
    public DateTimeOffset? CreatedAtUtc { get; init; }
    public DateTimeOffset? UpdatedAtUtc { get; init; }
}
