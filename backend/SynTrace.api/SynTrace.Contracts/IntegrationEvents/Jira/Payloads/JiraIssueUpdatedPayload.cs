namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraIssueUpdatedPayload
{
    public string IssueId { get; init; } = string.Empty;

    public string IssueKey { get; init; } = string.Empty;

    public string? ProjectId { get; init; }

    public string? ProjectKey { get; init; }

    public string? Summary { get; init; }

    public IReadOnlyList<JiraFieldChange> Changes { get; init; }
        = Array.Empty<JiraFieldChange>();
}

public sealed record JiraFieldChange
{
    public string Field { get; init; } = string.Empty;

    public string? From { get; init; }

    public string? To { get; init; }
}