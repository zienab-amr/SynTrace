namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraSprintPayload
{
    public string SprintId { get; init; } = string.Empty;
    public string? Name { get; init; }
    public string? State { get; init; }
    public string? BoardId { get; init; }
    public DateTimeOffset? StartDateUtc { get; init; }
    public DateTimeOffset? EndDateUtc { get; init; }
    public DateTimeOffset? CompleteDateUtc { get; init; }
}
