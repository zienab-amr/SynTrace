using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Features.Integrations.Jira.Commands.CallBack;
using SynTrace.Application.Features.Integrations.Jira.Queries.ConnectJira;

namespace SynTrace_api.Controllers
{
    [Route("api/integrations/[controller]")]
    [ApiController]
    public class JiraController : ControllerBase
    {
        private readonly IMediator _mediator;
        public JiraController(IMediator mediator)
        {
            _mediator = mediator;
        }

        [Authorize]
        [HttpGet("connect-jira")]
        public async Task<IActionResult> ConnectJira()
        {
            var query = new ConnectJiraCommand();
            var result = await _mediator.Send(query);
            return Redirect(result);
        }

        [AllowAnonymous]
        [HttpGet("callback")]
        public async Task<IActionResult> CallBack(
        [FromQuery] string? code,
        [FromQuery] string? state,
        [FromQuery] string? error,
        CancellationToken cancellationToken)
        {
            if (!string.IsNullOrWhiteSpace(error))
                return BadRequest("Jira authorization was not completed.");

            if (string.IsNullOrWhiteSpace(code) ||
                string.IsNullOrWhiteSpace(state))
            {
                return BadRequest("Missing OAuth callback parameters.");
            }

            await _mediator.Send(new CallBackCommand
            {
                Code = code,
                State = state
            }, cancellationToken);

            return Ok(new { message = "Jira connection completed." });
        }
    }
}
