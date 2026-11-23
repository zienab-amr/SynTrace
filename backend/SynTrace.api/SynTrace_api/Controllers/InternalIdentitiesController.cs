using System.Security.Cryptography;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using SynTrace.Application.Features.Integrations.Identities.Queries.GetInternalEmployeeIdentities;
using SynTrace.Infrastructure.Options;

namespace SynTrace.Api.Controllers;

/// <summary>
/// Service-to-service identity map for the AI consumer. Never authenticate this
/// endpoint using a user-provided company ID or expose it as a regular user API.
/// </summary>
[ApiController]
[AllowAnonymous] // Authenticated with the internal AI service key, not with a user JWT.
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Route("api/internal/identities")]
public sealed class InternalIdentitiesController(IMediator mediator, IOptions<AiServiceOptions> options)
    : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetIdentities([FromQuery] string? companyId, CancellationToken ct)
    {
        if (!HasValidInternalKey())
            return Unauthorized();
        if (string.IsNullOrWhiteSpace(companyId) || companyId.Length > 450)
            return BadRequest(new { message = "A valid companyId is required." });

        var identities = await mediator.Send(new GetInternalEmployeeIdentitiesQuery(companyId), ct);
        return Ok(new { items = identities });
    }

    private bool HasValidInternalKey()
    {
        var expected = options.Value.ApiKey;
        if (string.IsNullOrWhiteSpace(expected) ||
            !Request.Headers.TryGetValue("X-Internal-Api-Key", out var provided) ||
            provided.Count != 1 || string.IsNullOrWhiteSpace(provided[0]))
            return false;

        // Hashing both sides first makes the fixed-time comparison length-independent.
        return CryptographicOperations.FixedTimeEquals(
            SHA256.HashData(Encoding.UTF8.GetBytes(expected)),
            SHA256.HashData(Encoding.UTF8.GetBytes(provided[0]!)));
    }
}
