using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts.Knowledge;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Services.Knowledge;

namespace SynTrace.Api.Controllers;

[ApiController]
[AllowAnonymous] // The existing AI service key is required on every action.
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Route("api/internal/knowledge")]
public sealed class InternalKnowledgeController(KnowledgeSourceService sources, IOptions<AiServiceOptions> options) : ControllerBase
{
    [HttpGet("pending")]
    public Task<IActionResult> Pending([FromQuery, Required, StringLength(450)] string companyId,
        [FromQuery, Range(1, 25)] int take = 5, CancellationToken ct = default) =>
        RunAsync(async () => Ok(await sources.PendingAsync(companyId, take, ct)));

    [HttpGet("sources/{id:guid}/versions/{version:int:min(1)}/pdf")]
    public Task<IActionResult> ReadPdf(Guid id, int version, [FromQuery, Required, StringLength(450)] string companyId,
        CancellationToken ct) =>
        RunAsync(async () => File(await sources.ReadPendingPdfAsync(companyId, id, version, ct),
            "application/octet-stream", "source.pdf"));

    [HttpPost("sources/{id:guid}/versions/{version:int:min(1)}/extraction")]
    [RequestSizeLimit(4 * 1024 * 1024)]
    public Task<IActionResult> Submit(Guid id, int version, [FromQuery, Required, StringLength(450)] string companyId,
        KnowledgeExtractionRequest request, CancellationToken ct) =>
        RunAsync(async () => { await sources.SubmitInternalExtractionAsync(companyId, id, version, request, ct); return NoContent(); });

    [HttpGet("changes")]
    public Task<IActionResult> Changes([FromQuery, Required, StringLength(450)] string companyId,
        [FromQuery, Range(0, long.MaxValue)] long after = 0,
        [FromQuery, Range(1, 100)] int take = 20, CancellationToken ct = default) =>
        RunAsync(async () => Ok(await sources.ReadChangesAsync(companyId, after, take, ct)));

    [HttpGet("sources/{id:guid}/versions/{version:int:min(1)}/published")]
    public Task<IActionResult> Published(Guid id, int version,
        [FromQuery, Required, StringLength(450)] string companyId,
        [FromQuery, Required, StringLength(450)] string projectId, CancellationToken ct) =>
        RunAsync(async () => Ok(await sources.ReadPublishedAsync(companyId, projectId, id, version, ct)));

    private async Task<IActionResult> RunAsync(Func<Task<IActionResult>> action)
    {
        var expected = options.Value.ApiKey;
        var hasKey = Request.Headers.TryGetValue("X-Internal-Api-Key", out var header);
        if (!hasKey || header.Count != 1 || string.IsNullOrWhiteSpace(expected) ||
            !CryptographicOperations.FixedTimeEquals(SHA256.HashData(Encoding.UTF8.GetBytes(expected)),
                SHA256.HashData(Encoding.UTF8.GetBytes(header.ToString()))))
            return Unauthorized();
        try { return await action(); }
        catch (KnowledgeSourceException ex) { return Problem(statusCode: ex.Status, detail: ex.Message); }
    }
}
