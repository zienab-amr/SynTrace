namespace SynTrace.Application.Integrations.Jira;

public sealed record JiraWebhookRegistration(long WebhookId, DateTime ExpiresAtUtc);

public interface IJiraWebhookRegistrationService
{
    Task<JiraWebhookRegistration> RegisterAsync(string connectionId, CancellationToken cancellationToken = default);

    Task<bool> RefreshAsync(string connectionId, CancellationToken cancellationToken = default);
}
