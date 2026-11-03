namespace SynTrace.Application.Integrations.Jira;

public sealed record JiraAdminWebhookSetup(string Url, string Secret, IReadOnlyList<string> Events);

public sealed record JiraAdminWebhookStatus(bool Configured, DateTime? LastReceivedAt);

public interface IJiraConnectionAdminService
{
    /// <summary>Creates a new secret, replacing any previous one. It is returned only here.</summary>
    Task<JiraAdminWebhookSetup?> SetupAdminWebhookAsync(string companyId, CancellationToken cancellationToken);

    Task<JiraAdminWebhookStatus?> GetAdminWebhookStatusAsync(string companyId, CancellationToken cancellationToken);

    /// <summary>Stops the integration and deletes the company's Jira data here and on the AI side.</summary>
    Task<bool> DisconnectAsync(string companyId, string correlationId, CancellationToken cancellationToken);
}
