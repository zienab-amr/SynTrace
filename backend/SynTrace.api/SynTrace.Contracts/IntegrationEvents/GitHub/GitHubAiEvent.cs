using System.Text.Json;

namespace SynTrace.Contracts.IntegrationEvents.GitHub;

/// <summary>Provider-normalized GitHub data from the sync pipeline.</summary>
public sealed record GitHubAiEvent(
    string EventId,
    string EventType,
    string CompanyId,
    string ProjectId,
    string BindingId,
    long InstallationId,
    long RepositoryId,
    string EntityId,
    long SourceVersion,
    DateTime OccurredAtUtc,
    JsonElement Payload)
{
    public int SchemaVersion => 1;
}
