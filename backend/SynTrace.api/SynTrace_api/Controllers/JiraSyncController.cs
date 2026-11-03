using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Contracts;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Api.Controllers
{
    [ApiController]
    [Authorize(Roles = "Admin")]
    [Route("api/integrations/jira/sync")]
    public class JiraSyncController : ControllerBase
    {
        private readonly ICurrentTenant _tenant;
        private readonly IJiraOAuthConnectionRepository _connections;
        private readonly IJiraBackfillQueue _queue;
        private readonly IJiraWebhookRegistrationService _registration;

        public JiraSyncController(
            ICurrentTenant tenant,
            IJiraOAuthConnectionRepository connections,
            IJiraBackfillQueue queue,
            IJiraWebhookRegistrationService registration)
        {
            _tenant = tenant;
            _connections = connections;
            _queue = queue;
            _registration = registration;
        }

        /// <summary>Starts the historical import. Pass reregisterWebhook=true to also (re)create the webhook.</summary>
        [HttpPost]
        public async Task<IActionResult> Start([FromQuery] bool reregisterWebhook, CancellationToken cancellationToken)
        {
            var connection = await _connections.GetActiveCompanyConnection(_tenant.CompanyId);
            if (connection is null)
                return NotFound(new { message = "Connect Jira first." });

            if (reregisterWebhook || connection.WebhookId is null)
                await _registration.RegisterAsync(connection.Id, cancellationToken);

            await _queue.EnqueueAsync(connection.Id, cancellationToken);
            return Accepted(new { message = "Jira sync queued." });
        }

        [HttpGet("status")]
        public async Task<IActionResult> Status()
        {
            var c = await _connections.GetActiveCompanyConnection(_tenant.CompanyId);
            if (c is null) return NotFound(new { message = "Connect Jira first." });

            return Ok(new
            {
                site = c.SiteUrl,
                syncStatus = c.SyncStatus.ToString(),
                lastSyncedAt = c.LastSyncedAt,
                lastSyncError = c.LastSyncError,
                webhookRegistered = c.WebhookId != null,
                webhookExpiresAt = c.WebhookExpiresAt
            });
        }
    }
}
