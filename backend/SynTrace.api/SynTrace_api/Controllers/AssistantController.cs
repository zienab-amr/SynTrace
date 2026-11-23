using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SynTrace.Application.Features.Assistant.Commands.AskAssistant;
using SynTrace.Application.Features.Assistant.Commands.DeleteConversation;
using SynTrace.Application.Features.Assistant.Queries.GetConversationMessages;
using SynTrace.Application.Features.Assistant.Queries.GetConversations;

namespace SynTrace.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/assistant")]
public sealed class AssistantController(IMediator mediator) : ControllerBase
{
    public const string RateLimitPolicy = "assistant";

    [HttpPost("ask")]
    [EnableRateLimiting(RateLimitPolicy)]
    public async Task<IActionResult> Ask([FromBody] AskAssistantCommand request, CancellationToken ct)
        => Ok(await mediator.Send(request, ct));

    [HttpGet("conversations")]
    public async Task<IActionResult> GetConversations(CancellationToken ct)
        => Ok(await mediator.Send(new GetConversationsQuery(), ct));

    [HttpGet("conversations/{id}/messages")]
    public async Task<IActionResult> GetMessages(string id, CancellationToken ct)
        => Ok(await mediator.Send(new GetConversationMessagesQuery(id), ct));

    [HttpDelete("conversations/{id}")]
    public async Task<IActionResult> DeleteConversation(string id, CancellationToken ct)
    {
        await mediator.Send(new DeleteConversationCommand(id), ct);
        return NoContent();
    }
}
