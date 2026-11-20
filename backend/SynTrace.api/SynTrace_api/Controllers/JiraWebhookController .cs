using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Integrations.Jira;

namespace SynTrace.Api.Controllers
{
  
    [ApiController]
    [AllowAnonymous]  
    [Route("api/integrations/jira/webhook")]
    public class JiraWebhookController : ControllerBase
    {
        private const long MaxBodyBytes = 26 * 1024 * 1024;   // Jira sends webhooks up to 25 MB

        private readonly IJiraWebhookIngestionService _ingestion;

        public JiraWebhookController(IJiraWebhookIngestionService ingestion)
        {
            _ingestion = ingestion;
        }

        [HttpPost("{connectionId}")]
        [RequestSizeLimit(MaxBodyBytes)]
        public async Task<IActionResult> Receive(
            string connectionId,
            [FromQuery] string? secret,
            CancellationToken cancellationToken)
        {
            // Raw bytes are needed for HMAC verification, so we do not use model binding.
            using var buffer = new MemoryStream();
            await Request.Body.CopyToAsync(buffer, cancellationToken);

            var correlationId = Request.Headers["X-Correlation-Id"].FirstOrDefault() ?? Guid.NewGuid().ToString("N");
            var signature = Request.Headers["X-Hub-Signature"].FirstOrDefault();

            var authorization = Request.Headers.Authorization.FirstOrDefault();

            var result = await _ingestion.IngestAsync(
                connectionId, secret, signature, authorization, buffer.ToArray(), correlationId, cancellationToken);

            return ToResponse(result, correlationId);
        }

        /// <summary>Webhook created by the customer's Jira admin, for events OAuth webhooks do not deliver.</summary>
        [HttpPost("{connectionId}/admin")]
        [RequestSizeLimit(MaxBodyBytes)]
        public async Task<IActionResult> ReceiveAdmin(string connectionId, CancellationToken cancellationToken)
        {
            using var buffer = new MemoryStream();
            await Request.Body.CopyToAsync(buffer, cancellationToken);

            var correlationId = Request.Headers["X-Correlation-Id"].FirstOrDefault() ?? Guid.NewGuid().ToString("N");
            var signature = Request.Headers["X-Hub-Signature"].FirstOrDefault();

            var result = await _ingestion.IngestAdminAsync(
                connectionId, signature, buffer.ToArray(), correlationId, cancellationToken);

            return ToResponse(result, correlationId);
        }

        private IActionResult ToResponse(JiraWebhookIngestionResult result, string correlationId)
        {

            return result.Status switch
            {
                JiraWebhookIngestionStatus.Accepted => Accepted(new { eventId = result.EventId, correlationId }),
                JiraWebhookIngestionStatus.Ignored => Ok(new { status = "ignored" }),           // 2xx so Jira does not retry
                JiraWebhookIngestionStatus.Unauthorized => Unauthorized(),
                JiraWebhookIngestionStatus.BadRequest => BadRequest(new { message = result.Message }),
                _ => StatusCode(StatusCodes.Status503ServiceUnavailable)                         // broker down => Jira retries
            };
        }
    }
}
