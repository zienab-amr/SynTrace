using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

public sealed class JiraWebhookRegistrationService : IJiraWebhookRegistrationService
{
    
    private static readonly string[] SupportedEvents =
    {
        "jira:issue_created", "jira:issue_updated", "jira:issue_deleted",
        "comment_created", "comment_updated", "comment_deleted",
        "sprint_created", "sprint_updated", "sprint_deleted", "sprint_started", "sprint_closed",
        "jira:version_released", "jira:version_unreleased", "jira:version_created", "jira:version_moved",
        "jira:version_updated", "jira:version_merged", "jira:version_deleted"
    };

    private readonly JiraApiClient _api;
    private readonly SynTraceDbContext _db;
    private readonly JiraOAuthOptions _options;
    private readonly ILogger<JiraWebhookRegistrationService> _logger;

    public JiraWebhookRegistrationService(
        JiraApiClient api,
        SynTraceDbContext db,
        IOptions<JiraOAuthOptions> options,
        ILogger<JiraWebhookRegistrationService> logger)
    {
        _api = api;
        _db = db;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<JiraWebhookRegistration> RegisterAsync(string connectionId, CancellationToken cancellationToken = default)
    {
        var baseUrl = _options.WebhookBaseUrl.TrimEnd('/');
        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var baseUri) || baseUri.Scheme != Uri.UriSchemeHttps)
            throw new InvalidOperationException("Jira WebhookBaseUrl must be a valid HTTPS URL.");

        var connection = await _db.JiraConnections.SingleOrDefaultAsync(c => c.Id == connectionId && c.status, cancellationToken)
            ?? throw new InvalidOperationException("Active Jira connection was not found.");

        // Drop the previous registration (best effort) so we never accumulate duplicate webhooks.
        if (connection.WebhookId is { } oldId)
        {
            try
            {
                using var _ = await _api.SendAsync(connectionId, HttpMethod.Delete, "/rest/api/3/webhook",
                    new { webhookIds = new[] { oldId } }, cancellationToken);
            }
            catch (HttpRequestException ex)
            {
                _logger.LogWarning(ex, "Could not delete old Jira webhook {WebhookId}; continuing.", oldId);
            }
        }

        // Jira REQUIRES a non-empty, bounded jqlFilter for issue events -> scope it to the project keys.
        var projectKeys = await GetProjectKeysAsync(connectionId, cancellationToken);
        if (projectKeys.Count == 0)
            throw new InvalidOperationException("The Jira site has no projects visible to this account; nothing to subscribe to.");

        var jql = "project in (" + string.Join(",", projectKeys.Select(k => $"\"{k}\"")) + ")";

        var secret = JiraWebhookSecurity.GenerateSecret();
        var callbackUrl = $"{baseUrl}/api/integrations/jira/webhook/{Uri.EscapeDataString(connectionId)}?secret={secret}";

        var body = new
        {
            url = callbackUrl,
            webhooks = new[] { new { events = SupportedEvents, jqlFilter = jql } }
        };

        using var document = await _api.SendAsync(connectionId, HttpMethod.Post, "/rest/api/3/webhook", body, cancellationToken)
            ?? throw new InvalidOperationException("Jira returned an empty webhook registration response.");

        var root = document.RootElement;
        if (!root.TryGetProperty("webhookRegistrationResult", out var results) || results.GetArrayLength() == 0)
            throw new InvalidOperationException("Jira returned an unexpected webhook registration response.");

        var registration = results[0];

        if (registration.TryGetProperty("errors", out var errors) && errors.ValueKind == JsonValueKind.Array && errors.GetArrayLength() > 0)
        {
            var messages = string.Join(", ", errors.EnumerateArray().Select(x => x.GetString()));
            throw new InvalidOperationException($"Jira rejected webhook registration: {messages}");
        }

        if (!registration.TryGetProperty("createdWebhookId", out var idElement))
            throw new InvalidOperationException("Jira did not return a created webhook ID.");

        var webhookId = idElement.GetInt64();
        var expires = DateTime.UtcNow.AddDays(30);

        connection.WebhookId = webhookId;
        connection.WebhookSecretHash = JiraWebhookSecurity.Hash(secret);   // only the hash is stored
        connection.WebhookExpiresAt = expires;
        connection.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Registered Jira webhook {WebhookId} for connection {ConnectionId} ({Count} projects).",
            webhookId, connectionId, projectKeys.Count);

        return new JiraWebhookRegistration(webhookId, expires);
    }

    public async Task<bool> RefreshAsync(string connectionId, CancellationToken cancellationToken = default)
    {
        var connection = await _db.JiraConnections.SingleOrDefaultAsync(c => c.Id == connectionId && c.status, cancellationToken);
        if (connection?.WebhookId is not { } webhookId) return false;

        // PUT /webhook/refresh silently ignores unknown ids, so first confirm Jira still has this webhook.
        if (!await WebhookExistsAsync(connectionId, webhookId, cancellationToken)) return false;

        using var doc = await _api.SendAsync(connectionId, HttpMethod.Put, "/rest/api/3/webhook/refresh",
            new { webhookIds = new[] { webhookId } }, cancellationToken);

        var expires = DateTime.UtcNow.AddDays(30);
        if (doc is not null && JiraJson.ParseDate(doc.RootElement.Str("expirationDate")) is { } parsed)
            expires = parsed.UtcDateTime;

        connection.WebhookExpiresAt = expires;
        connection.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<bool> WebhookExistsAsync(string connectionId, long webhookId, CancellationToken ct)
    {
        var startAt = 0;
        while (true)
        {
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/api/3/webhook?startAt={startAt}&maxResults=100", cancellationToken: ct);
            if (doc is null) return false;

            var values = doc.RootElement.Arr("values");
            if (values is null) return false;

            var count = 0;
            foreach (var v in values.Value.EnumerateArray())
            {
                count++;
                if (v.Long("id") == webhookId) return true;
            }

            if (doc.RootElement.Bool("isLast") != false || count == 0) return false;
            startAt += count;
        }
    }

    private async Task<List<string>> GetProjectKeysAsync(string connectionId, CancellationToken ct)
    {
        var keys = new List<string>();
        var startAt = 0;
        while (true)
        {
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/api/3/project/search?startAt={startAt}&maxResults=50", cancellationToken: ct);
            if (doc is null) break;

            var count = 0;
            if (doc.RootElement.Arr("values") is { } values)
            {
                foreach (var p in values.EnumerateArray())
                {
                    count++;
                    if (p.Str("key") is { } key) keys.Add(key);
                }
            }

            if (doc.RootElement.Bool("isLast") != false || count == 0) break;
            startAt += count;
        }
        return keys;
    }
}
