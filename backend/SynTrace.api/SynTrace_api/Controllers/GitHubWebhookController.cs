using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Infrastructure.Integrations.GitHub;

namespace SynTrace.Api.Controllers;

[ApiController]
[AllowAnonymous]
[Route("api/integrations/github/webhook")]
public sealed class GitHubWebhookController(IGitHubWebhookIngress ingress) : ControllerBase
{
    [HttpPost]
    [RequestSizeLimit(GitHubWebhookIngress.MaxBodyBytes)]
    public async Task<IActionResult> Receive(CancellationToken cancellationToken)
    {
        if (Request.ContentLength > GitHubWebhookIngress.MaxBodyBytes)
            return StatusCode(StatusCodes.Status413PayloadTooLarge);

        var result = await ingress.ReceiveAsync(Request.Body,
            SingleHeader("X-Hub-Signature-256"), SingleHeader("X-GitHub-Delivery"), SingleHeader("X-GitHub-Event"),
            cancellationToken);
        return result switch
        {
            GitHubWebhookReceipt.Accepted => Accepted(),
            GitHubWebhookReceipt.Duplicate or GitHubWebhookReceipt.Ignored => Ok(),
            GitHubWebhookReceipt.Unauthorized => Unauthorized(),
            GitHubWebhookReceipt.Invalid => BadRequest(),
            GitHubWebhookReceipt.TooLarge => StatusCode(StatusCodes.Status413PayloadTooLarge),
            _ => StatusCode(StatusCodes.Status503ServiceUnavailable)
        };
    }

    private string? SingleHeader(string name) =>
        Request.Headers.TryGetValue(name, out var value) && value.Count == 1 ? value[0] : null;
}
