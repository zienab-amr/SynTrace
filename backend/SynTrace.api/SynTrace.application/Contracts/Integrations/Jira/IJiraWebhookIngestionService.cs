using SynTrace.Contracts.IntegrationEvents.Jira;

namespace SynTrace.Application.Integrations.Jira;

public enum JiraWebhookIngestionStatus { Accepted, Ignored, Unauthorized, BadRequest, PublishFailed }

public sealed record JiraWebhookIngestionResult(JiraWebhookIngestionStatus Status, string? EventId = null, string? Message = null);

public interface IJiraWebhookIngestionService
{
    Task<JiraWebhookIngestionResult> IngestAsync(
        string connectionId,
        string? secret,
        string? signatureHeader,
        byte[] rawBody,
        string correlationId,
        CancellationToken cancellationToken);
}

public enum JiraEventProcessingResult { Processed, Duplicate }

public interface IJiraEventProcessor
{
    Task<JiraEventProcessingResult> ProcessAsync(CanonicalJiraEvent jiraEvent, CancellationToken cancellationToken);
}

public interface IJiraBackfillService
{
    Task RunAsync(string connectionId, CancellationToken cancellationToken);
}

public interface IJiraBackfillQueue
{
    ValueTask EnqueueAsync(string connectionId, CancellationToken cancellationToken = default);
}
