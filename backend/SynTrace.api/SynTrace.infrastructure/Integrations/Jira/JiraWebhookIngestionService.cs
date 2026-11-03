using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Application.Messaging;
using SynTrace.Contracts.Validation;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

public sealed class JiraWebhookIngestionService : IJiraWebhookIngestionService
{
    private readonly SynTraceDbContext _db;
    private readonly JiraWebhookNormalizer _normalizer;
    private readonly IJiraEventPublisher _publisher;
    private readonly JiraWebhookOptions _options;
    private readonly ILogger<JiraWebhookIngestionService> _logger;

    public JiraWebhookIngestionService(
        SynTraceDbContext db,
        JiraWebhookNormalizer normalizer,
        IJiraEventPublisher publisher,
        IOptions<JiraWebhookOptions> options,
        ILogger<JiraWebhookIngestionService> logger)
    {
        _db = db;
        _normalizer = normalizer;
        _publisher = publisher;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<JiraWebhookIngestionResult> IngestAsync(
        string connectionId,
        string? secret,
        string? signatureHeader,
        byte[] rawBody,
        string correlationId,
        CancellationToken cancellationToken)
    {
        if (rawBody.Length == 0 || rawBody.Length > _options.MaxBodyBytes)
            return new(JiraWebhookIngestionStatus.BadRequest, Message: "Body is empty or too large.");

        // 1) Authenticate: connection must exist + secret must match. Same answer for both failures (no enumeration).
        var connection = await _db.JiraConnections
            .AsNoTracking()
            .Where(c => c.Id == connectionId && c.status && c.JiraConnectionType == JiraConnectionType.Company)
            .Select(c => new { c.Id, c.CompanyId, c.WebhookSecretHash })
            .SingleOrDefaultAsync(cancellationToken);

        if (connection is null || !JiraWebhookSecurity.VerifySecret(secret, connection.WebhookSecretHash))
        {
            _logger.LogWarning("Rejected Jira webhook for connection {ConnectionId}: invalid connection or secret.", connectionId);
            return new(JiraWebhookIngestionStatus.Unauthorized);
        }

        // 2) Optional HMAC (X-Hub-Signature) on top of the URL secret.
        if (!string.IsNullOrEmpty(_options.HmacSecret))
        {
            var valid = JiraWebhookSecurity.VerifyHmac(rawBody, signatureHeader, _options.HmacSecret);
            if (!valid && (_options.RequireHmac || !string.IsNullOrEmpty(signatureHeader)))
            {
                _logger.LogWarning("Rejected Jira webhook for connection {ConnectionId}: bad HMAC signature.", connectionId);
                return new(JiraWebhookIngestionStatus.Unauthorized);
            }
        }

        // 3) Parse.
        JsonDocument document;
        try { document = JsonDocument.Parse(rawBody); }
        catch (JsonException) { return new(JiraWebhookIngestionStatus.BadRequest, Message: "Invalid JSON."); }

        using (document)
        {
            var root = document.RootElement;
            var now = DateTimeOffset.UtcNow;

            // 4) Replay / staleness window (SYNT-313).
            if (_options.MaxEventAgeMinutes > 0 && root.ValueKind == JsonValueKind.Object && root.Long("timestamp") is { } ms)
            {
                var age = now - DateTimeOffset.FromUnixTimeMilliseconds(ms);
                if (age > TimeSpan.FromMinutes(_options.MaxEventAgeMinutes))
                    return new(JiraWebhookIngestionStatus.BadRequest, Message: "Event timestamp is outside the accepted window.");
            }

            // 5) Normalise to the canonical contract.
            var canonical = _normalizer.Normalize(root, connection.CompanyId, connection.Id, correlationId, now);
            if (canonical is null)
                return new(JiraWebhookIngestionStatus.Ignored, Message: "Unsupported or malformed event.");

            var errors = CanonicalJiraEventValidator.Validate(canonical);
            if (errors.Count > 0)
                return new(JiraWebhookIngestionStatus.BadRequest, Message: string.Join(" ", errors));

            // 6) Publish. Failure => 5xx so Jira retries (retry w/ back-off is built into Jira Cloud).
            try
            {
                await _publisher.PublishAsync(canonical, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish Jira event {EventId} (correlation {CorrelationId}).",
                    canonical.EventId, correlationId);
                return new(JiraWebhookIngestionStatus.PublishFailed, canonical.EventId);
            }

            _logger.LogInformation(
                "Accepted Jira webhook {SourceEvent} -> {EventType} {EventId} (correlation {CorrelationId}, tenant {TenantId})",
                canonical.SourceEventName, canonical.EventType, canonical.EventId, correlationId, canonical.CompanyId);

            return new(JiraWebhookIngestionStatus.Accepted, canonical.EventId);
        }
    }
}
