using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Contracts;
using SynTrace.Application.Integrations.Jira;

namespace SynTrace.Api.Controllers
{
    [ApiController]
    [Authorize(Roles = "Admin")]
    [Route("api/integrations/jira")]
    public class JiraAdminWebhookController : ControllerBase
    {
        private readonly ICurrentTenant _tenant;
        private readonly IJiraConnectionAdminService _admin;

        public JiraAdminWebhookController(ICurrentTenant tenant, IJiraConnectionAdminService admin)
        {
            _tenant = tenant;
            _admin = admin;
        }

        /// <summary>Creates the URL and secret the admin enters in Jira. The secret is shown only once.</summary>
        [HttpPost("admin-webhook/setup")]
        public async Task<IActionResult> Setup(CancellationToken cancellationToken)
        {
            var setup = await _admin.SetupAdminWebhookAsync(_tenant.CompanyId, cancellationToken);
            return setup is null ? NotFound(new { message = "Connect Jira first." }) : Ok(setup);
        }

        [HttpGet("admin-webhook/status")]
        public async Task<IActionResult> Status(CancellationToken cancellationToken)
        {
            var status = await _admin.GetAdminWebhookStatusAsync(_tenant.CompanyId, cancellationToken);
            return status is null ? NotFound(new { message = "Connect Jira first." }) : Ok(status);
        }

        [HttpDelete("connection")]
        public async Task<IActionResult> Disconnect(CancellationToken cancellationToken)
        {
            var correlationId = Request.Headers["X-Correlation-Id"].FirstOrDefault() ?? Guid.NewGuid().ToString("N");
            var done = await _admin.DisconnectAsync(_tenant.CompanyId, correlationId, cancellationToken);
            return done
                ? Ok(new { message = "Jira disconnected. Delete the SynTrace admin webhook from Jira settings." })
                : NotFound(new { message = "Connect Jira first." });
        }
    }
}
