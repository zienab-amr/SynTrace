using SynTrace.Contracts.IntegrationEvents.GitHub;

namespace SynTrace.Application.Integrations.GitHub;

public interface IGitHubSyncTrigger
{
    Task RequestSyncAsync(string companyId, long installationId, long? repositoryId,
        string eventName, string? action, CancellationToken cancellationToken);
}

public interface IGitHubAiPublisher
{
    Task PublishAsync(GitHubAiEvent message, CancellationToken cancellationToken);
}

public interface IGitHubWebhookIngress
{
    Task<GitHubWebhookReceipt> ReceiveAsync(Stream body, string? signature, string? delivery,
        string? eventName, CancellationToken cancellationToken);
}

public enum GitHubWebhookReceipt { Accepted, Duplicate, Ignored, Unauthorized, Invalid, TooLarge, Unavailable }
