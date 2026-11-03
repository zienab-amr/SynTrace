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
        private readonly IJiraWebhookIngestionService _ingestion;

        public JiraWebhookController(IJiraWebhookIngestionService ingestion)
        {
            _ingestion = ingestion;
        }

        [HttpPost("{connectionId}")]
        [RequestSizeLimit(1_048_576)]
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

            var result = await _ingestion.IngestAsync(
                connectionId, secret, signature, buffer.ToArray(), correlationId, cancellationToken);

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
