using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Application.Messaging;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.Serialization;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

public sealed class JiraConnectionAdminService : IJiraConnectionAdminService
{
    /// <summary>What the admin selects in Jira. Issue and comment events are left out: OAuth delivers them.</summary>
    private static readonly string[] AdminEvents =
    {
        "project_created", "project_updated", "project_deleted", "project_soft_deleted",
        "project_restored_deleted", "project_archived", "project_restored_archived",
        "worklog_created", "worklog_updated", "worklog_deleted",
        "attachment_created", "attachment_deleted",
        "issuelink_created", "issuelink_deleted"
    };

    private readonly SynTraceDbContext _db;
    private readonly JiraApiClient _api;
    private readonly IJiraEventPublisher _publisher;
    private readonly JiraOAuthOptions _options;
    private readonly IDataProtector _protector;
    private readonly ILogger<JiraConnectionAdminService> _logger;

    public JiraConnectionAdminService(
        SynTraceDbContext db,
        JiraApiClient api,
        IJiraEventPublisher publisher,
        IOptions<JiraOAuthOptions> options,
        IDataProtectionProvider dataProtection,
        ILogger<JiraConnectionAdminService> logger)
    {
        _db = db;
        _api = api;
        _publisher = publisher;
        _options = options.Value;
        _protector = dataProtection.CreateProtector(JiraAdminWebhookSecret.ProtectorPurpose);
        _logger = logger;
    }

    public async Task<JiraAdminWebhookSetup?> SetupAdminWebhookAsync(string companyId, CancellationToken cancellationToken)
    {
        var baseUrl = _options.WebhookBaseUrl.TrimEnd('/');
        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var baseUri) || baseUri.Scheme != Uri.UriSchemeHttps)
            throw new InvalidOperationException("Jira WebhookBaseUrl must be a valid HTTPS URL.");

        var connection = await ActiveConnection(companyId).SingleOrDefaultAsync(cancellationToken);
        if (connection is null) return null;

        var secret = JiraWebhookSecurity.GenerateSecret();
        connection.EncryptedAdminWebhookSecret = _protector.Protect(secret);
        connection.AdminWebhookLastReceivedAt = null;
        connection.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        var url = $"{baseUrl}/api/integrations/jira/webhook/{Uri.EscapeDataString(connection.Id)}/admin";
        return new JiraAdminWebhookSetup(url, secret, AdminEvents);
    }

    public async Task<JiraAdminWebhookStatus?> GetAdminWebhookStatusAsync(string companyId, CancellationToken cancellationToken)
    {
        var connection = await ActiveConnection(companyId).AsNoTracking().SingleOrDefaultAsync(cancellationToken);
        if (connection is null) return null;

        // Configured means Jira has really reached us with a valid signature.
        return new JiraAdminWebhookStatus(connection.AdminWebhookLastReceivedAt is not null, connection.AdminWebhookLastReceivedAt);
    }

    public async Task<bool> DisconnectAsync(string companyId, string correlationId, CancellationToken cancellationToken)
    {
        var connection = await ActiveConnection(companyId).SingleOrDefaultAsync(cancellationToken);
        if (connection is null) return false;

        if (connection.WebhookId is { } webhookId)
        {
            try
            {
                using var _ = await _api.SendAsync(connection.Id, HttpMethod.Delete, "/rest/api/3/webhook",
                    new { webhookIds = new[] { webhookId } }, cancellationToken);
            }
            catch (HttpRequestException ex)
            {
                // It stops working anyway: the tokens are removed and the webhook expires within 30 days.
                _logger.LogWarning(ex, "Could not delete Jira webhook {WebhookId}; continuing.", webhookId);
            }
        }

        // Publish first: if the broker is down the request fails and nothing has been deleted.
        await _publisher.PublishAsync(new CanonicalJiraEvent
        {
            EventId = Guid.NewGuid().ToString("N"),
            EventType = JiraEventType.CompanyDisconnected,
            SourceEventName = "syntrace:company_disconnected",
            CompanyId = companyId,
            JiraConnectionId = connection.Id,
            CloudId = connection.CloudId,
            SiteUrl = connection.SiteUrl,
            CorrelationId = correlationId,
            ReceivedAtUtc = DateTimeOffset.UtcNow,
            Payload = JsonSerializer.SerializeToElement(new Dictionary<string, object>(), JiraEventContractJson.Options)
        }, cancellationToken);

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

        await _db.JiraComments.Where(x => x.CompanyId == companyId).ExecuteDeleteAsync(cancellationToken);
        await _db.JiraIssues.Where(x => x.CompanyId == companyId).ExecuteDeleteAsync(cancellationToken);
        await _db.JiraSprints.Where(x => x.CompanyId == companyId).ExecuteDeleteAsync(cancellationToken);
        await _db.JiraProjects.Where(x => x.CompanyId == companyId).ExecuteDeleteAsync(cancellationToken);
        await _db.JiraUsers.Where(x => x.CompanyId == companyId).ExecuteDeleteAsync(cancellationToken);
        await _db.ProcessedJiraEvents.Where(x => x.CompanyId == companyId).ExecuteDeleteAsync(cancellationToken);

        connection.status = false;
        connection.EncryptedAccessToken = string.Empty;
        connection.EncryptedRefreshToken = null;
        connection.EncryptedAdminWebhookSecret = null;
        connection.WebhookId = null;
        connection.WebhookSecretHash = null;
        connection.WebhookExpiresAt = null;
        connection.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return true;
    }

    private IQueryable<Domain.Entities.Jira.JiraConnection> ActiveConnection(string companyId) =>
        _db.JiraConnections.Where(c => c.CompanyId == companyId && c.status && c.JiraConnectionType == JiraConnectionType.Company);
}
