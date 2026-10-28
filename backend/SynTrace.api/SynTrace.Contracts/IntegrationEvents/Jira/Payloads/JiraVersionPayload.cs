namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

public sealed record JiraVersionPayload
{
    public string VersionId { get; init; } = string.Empty;
    public string? ProjectId { get; init; }
    public string? ProjectKey { get; init; }
    public string? Name { get; init; }
    public bool? Released { get; init; }
    public bool? Archived { get; init; }
    public DateOnly? ReleaseDate { get; init; }
    public string? MergedToVersionId { get; init; }
}
