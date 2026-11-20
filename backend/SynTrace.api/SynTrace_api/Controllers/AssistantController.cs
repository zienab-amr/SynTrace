using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Infrastructure.Persistence.Context;

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
        private readonly SynTraceDbContext _db;
        private readonly IAssistantClient _assistant;

        public AssistantController(
            ICurrentTenant tenant,
            ICurrentEmployee employee,
            SynTraceDbContext db,
            IAssistantClient assistant)
        {
            _tenant = tenant;
            _employee = employee;
            _db = db;
            _assistant = assistant;
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
            var projects = await _db.JiraProjects.AsNoTracking()
                .Where(p => p.CompanyId == companyId && p.Key != null)
                .Select(p => p.Key!)
                .ToListAsync(cancellationToken);

            var correlationId = Request.Headers["X-Correlation-Id"].FirstOrDefault() ?? Guid.NewGuid().ToString("N");
            var result = await _assistant.AskAsync(
                question, companyId, _employee.EmployeeId, projects, correlationId, cancellationToken);

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
