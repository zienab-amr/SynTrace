namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraBoardPayload
{
    public string BoardId { get; init; } = string.Empty;
    public string? Name { get; init; }
    public string? BoardType { get; init; }
}
