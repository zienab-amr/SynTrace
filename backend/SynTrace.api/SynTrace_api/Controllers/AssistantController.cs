using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Infrastructure.Services.Assistant;
using SynTrace.Infrastructure.Options;

namespace SynTrace.Api.Controllers
{
    public sealed record AskRequest(string? Question);

    [ApiController]
    [Authorize]
    [Route("api/assistant")]
    public class AssistantController : ControllerBase
    {
        public const string RateLimitPolicy = "assistant";
        private const int MaxQuestionLength = 2000;

        private readonly ICurrentTenant _tenant;
        private readonly ICurrentEmployee _employee;
        private readonly AssistantProjectAccess _projectAccess;
        private readonly IAssistantClient _assistant;
        private readonly AiServiceOptions _options;

        public AssistantController(
            ICurrentTenant tenant,
            ICurrentEmployee employee,
            AssistantProjectAccess projectAccess,
            IAssistantClient assistant,
            IOptions<AiServiceOptions> options)
        {
            _tenant = tenant;
            _employee = employee;
            _projectAccess = projectAccess;
            _assistant = assistant;
            _options = options.Value;
        }

        [HttpPost("ask")]
        [EnableRateLimiting(RateLimitPolicy)]
        public async Task<IActionResult> Ask([FromBody] AskRequest request, CancellationToken cancellationToken)
        {
            var question = request.Question?.Trim();
            if (string.IsNullOrEmpty(question) || question.Length > MaxQuestionLength)
                return BadRequest(new { message = $"Question must be 1 to {MaxQuestionLength} characters." });

            // The company and projects come from the JWT and the database, never from the client.
            var companyId = _tenant.CompanyId;
            var scope = await _projectAccess.GetScopeAsync(companyId, _employee.EmployeeId, cancellationToken);
            if (scope.JiraKeys.Count == 0 &&
                (!_options.EnableSynTraceProjectScope || scope.SynTraceProjectIds.Count == 0))
                return Forbid();

            var correlationId = Guid.NewGuid().ToString("N");
            var result = await _assistant.AskAsync(
                question, companyId, _employee.EmployeeId, scope, correlationId, cancellationToken);

            return result.Failure switch
            {
                AssistantFailure.None => Ok(result.Answer),
                AssistantFailure.BadRequest => BadRequest(new { message = "The question could not be processed." }),
                AssistantFailure.Misconfigured => StatusCode(StatusCodes.Status500InternalServerError,
                    new { message = "The assistant is not configured correctly." }),
                _ => StatusCode(StatusCodes.Status503ServiceUnavailable,
                    new { message = "The assistant is not available right now." })
            };
        }
    }
}
