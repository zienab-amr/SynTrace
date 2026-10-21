using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.Exceptions;
using SynTrace.Application.Features.Integrations.Jira.Commands.CallBack;
using SynTrace.Application.Features.Integrations.Jira.Commands.CompleteCompanyJiraConnection;
using SynTrace.Application.Features.Integrations.Jira.Commands.ConnectEmployeeJira;
using SynTrace.Application.Features.Integrations.Jira.Queries.ConnectJira;
using SynTrace.Application.Features.Integrations.Jira.Queries.GetPendingCompanyJiraSites;

namespace SynTrace_api.Controllers
{
    [Route("api/integrations/[controller]")]
    [ApiController]
    public class JiraController : ControllerBase
    {
        private readonly IMediator _mediator;
        private readonly IConfiguration _configuration;

        public JiraController(
            IMediator mediator,
            IConfiguration configuration)
        {
            _mediator = mediator;
            _configuration = configuration;
        }

        [Authorize(Roles = "Admin")]
        [HttpGet("connect-jira")]
        public async Task<IActionResult> ConnectJira()
        {
            var query = new ConnectCompanyJiraCommand();
            try
            {
                var result = await _mediator.Send(query);
                return Ok(result);
            }
            catch (CompanyJiraConnectionAlreadyExistsException ex)
            {
                return Conflict(ex.Message);
            }
        }

        [Authorize]
        [HttpGet("connect-employee-jira")]
        public async Task<IActionResult> ConnectEmployeeJira()
        {
            var query = new ConnectEmployeeJiraCommand();
            try
            {
                var result = await _mediator.Send(query);
                return Ok(result);
            }
            catch (EmployeeJiraConnectionAlreadyExistsException ex)
            {
                return Conflict(ex.Message);
            }
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

            try
            {
                var result = await _mediator.Send(
                    new CallBackCommand
                    {
                        Code = code,
                        State = state
                    },
                    cancellationToken);

                var frontendRedirectUri =
                    _configuration["JiraOAuth:FrontendRedirectUri"];

                if (string.IsNullOrWhiteSpace(frontendRedirectUri))
                {
                    return StatusCode(StatusCodes.Status500InternalServerError,
                        new { message = "Frontend redirect URI is not configured." });
                }

                var redirectUrl = QueryHelpers.AddQueryString(
                    frontendRedirectUri,
                    "status",
                    result.RequiresSiteSelection ? "select-site" : "success");

                if (result.PendingId is not null)
                {
                    redirectUrl = QueryHelpers.AddQueryString(
                        redirectUrl,
                        "pendingId",
                        result.PendingId);
                }

                return Ok(redirectUrl);
            }
            catch (CompanyJiraConnectionAlreadyExistsException ex)
            {
                return Conflict(new { message = ex.Message });
            }
            catch (EmployeeJiraConnectionAlreadyExistsException ex)
            {
                return Conflict(new { message = ex.Message });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpGet("pending-company-sites")]
        public async Task<IActionResult> GetPendingCompanySites(
    [FromQuery] string pendingId,
    CancellationToken cancellationToken)
        {
            try
            {
                var sites = await _mediator.Send(
                    new GetPendingCompanyJiraSitesQuery(pendingId),
                    cancellationToken);

                return Ok(sites);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return StatusCode(StatusCodes.Status410Gone,
                    new { message = ex.Message });
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpPost("complete-company-connection")]
        public async Task<IActionResult> CompleteCompanyConnection(
            [FromBody] CompleteCompanyJiraConnectionRequest request,
            CancellationToken cancellationToken)
        {
            try
            {
                await _mediator.Send(
                    new CompleteCompanyJiraConnectionCommand(
                        request.PendingId,
                        request.CloudId),
                    cancellationToken);

                return Ok(new { message = "Company Jira connection completed." });
            }
            catch (CompanyJiraConnectionAlreadyExistsException ex)
            {
                return Conflict(new { message = ex.Message });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return StatusCode(StatusCodes.Status410Gone,
                    new { message = ex.Message });
            }
            catch (UnauthorizedAccessException)
            {
                return Forbid();
            }
        }
    }
}
