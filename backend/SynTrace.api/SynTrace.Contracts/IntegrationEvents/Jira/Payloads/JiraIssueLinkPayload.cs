namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraIssueLinkPayload
{
    public string IssueLinkId { get; init; } = string.Empty;
    public string? LinkType { get; init; }
    public string? InwardIssueId { get; init; }
    public string? InwardIssueKey { get; init; }
    public string? OutwardIssueId { get; init; }
    public string? OutwardIssueKey { get; init; }
}
