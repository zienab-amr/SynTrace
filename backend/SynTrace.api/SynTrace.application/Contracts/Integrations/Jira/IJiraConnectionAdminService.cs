namespace SynTrace.Application.Integrations.Jira;

public sealed record JiraAdminWebhookSetup(string Url, string Secret, IReadOnlyList<string> Events);

public sealed record JiraAdminWebhookStatus(bool Configured, DateTime? LastReceivedAt);

public interface IJiraConnectionAdminService
{
    Task<JiraAdminWebhookSetup?> SetupAdminWebhookAsync(string companyId, CancellationToken cancellationToken);

    Task<JiraAdminWebhookStatus?> GetAdminWebhookStatusAsync(string companyId, CancellationToken cancellationToken);

    Task<bool> DisconnectAsync(string companyId, string correlationId, CancellationToken cancellationToken);
}
