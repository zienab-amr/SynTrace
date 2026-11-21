using System.ComponentModel.DataAnnotations;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Contracts.Knowledge;
using SynTrace.Infrastructure.Services.Knowledge;

namespace SynTrace.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/knowledge/sources")]
public sealed class KnowledgeSourcesController(KnowledgeSourceService sources) : ControllerBase
{
    private const int MaxUploadRequestBytes = 6 * 1024 * 1024;
    private static readonly UTF8Encoding Utf8 = new(false, true);

    [HttpPost]
    [Consumes("application/json")]
    [RequestSizeLimit(2 * 1024 * 1024)]
    public Task<IActionResult> Create(CreateKnowledgeSourceRequest request, CancellationToken ct) =>
        RunAsync(async () => CreatedSource(await sources.CreateAsync(request, TextContent(request.Text), ct)));

    [HttpPost("upload")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxUploadRequestBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = MaxUploadRequestBytes)]
    public Task<IActionResult> Upload([FromForm] CreateKnowledgeSourceRequest request,
        [FromForm, Required] IFormFile file, CancellationToken ct) =>
        RunAsync(async () => CreatedSource(await sources.CreateAsync(request, await ReadFileAsync(file, ct), ct)));

    [HttpPost("{id:guid}/versions")]
    [Consumes("application/json")]
    [RequestSizeLimit(2 * 1024 * 1024)]
    public Task<IActionResult> NewVersion(Guid id, AddKnowledgeVersionRequest request, CancellationToken ct) =>
        RunAsync(async () => Ok(await sources.AddVersionAsync(id, request, TextContent(request.Text), ct)));

    [HttpPost("{id:guid}/versions/upload")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxUploadRequestBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = MaxUploadRequestBytes)]
    public Task<IActionResult> UploadVersion(Guid id, [FromForm] AddKnowledgeVersionRequest request,
        [FromForm, Required] IFormFile file, CancellationToken ct) =>
        RunAsync(async () => Ok(await sources.AddVersionAsync(id, request, await ReadFileAsync(file, ct), ct)));

    [HttpGet]
    public Task<IActionResult> List([FromQuery, StringLength(450)] string? clientId,
        [FromQuery, StringLength(450)] string? projectId, [FromQuery, Range(0, int.MaxValue)] int skip = 0,
        [FromQuery, Range(1, 100)] int take = 20, CancellationToken ct = default) =>
        RunAsync(async () => Ok(await sources.ListAsync(clientId, projectId, skip, take, ct)));

    [HttpGet("{id:guid}")]
    public Task<IActionResult> Read(Guid id, [FromQuery, Range(1, int.MaxValue)] int? version, CancellationToken ct) =>
        RunAsync(async () => Ok(await sources.ReadAsync(id, version, ct)));

    [HttpPost("{id:guid}/versions/{version:int:min(1)}/extraction")]
    [RequestSizeLimit(4 * 1024 * 1024)]
    public Task<IActionResult> SubmitManual(Guid id, int version, KnowledgeExtractionRequest request, CancellationToken ct) =>
        RunAsync(async () => { await sources.SubmitManualExtractionAsync(id, version, request, ct); return NoContent(); });

    [HttpPost("{id:guid}/versions/{version:int:min(1)}/review")]
    public Task<IActionResult> Review(Guid id, int version, KnowledgeReviewRequest request, CancellationToken ct) =>
        RunAsync(async () => { await sources.ReviewAsync(id, version, request, ct); return NoContent(); });

    [HttpPost("{id:guid}/versions/{version:int:min(1)}/retry")]
    public Task<IActionResult> Retry(Guid id, int version, CancellationToken ct) =>
        RunAsync(async () => { await sources.RetryAsync(id, version, ct); return NoContent(); });

    [HttpPut("{id:guid}/project")]
    public Task<IActionResult> LinkProject(Guid id, KnowledgeProjectLinkRequest request, CancellationToken ct) =>
        RunAsync(async () => { await sources.LinkProjectAsync(id, request.ProjectId, ct); return NoContent(); });

    [HttpDelete("{id:guid}")]
    public Task<IActionResult> Withdraw(Guid id, CancellationToken ct) =>
        RunAsync(async () => { await sources.WithdrawAsync(id, ct); return NoContent(); });

    private async Task<IActionResult> RunAsync(Func<Task<IActionResult>> action)
    {
        try { return await action(); }
        catch (KnowledgeSourceException ex) { return Problem(statusCode: ex.Status, detail: ex.Message); }
    }

    private IActionResult CreatedSource(KnowledgeSourceSummary source) =>
        CreatedAtAction(nameof(Read), new { id = source.Id }, source);

    private static KnowledgeContent TextContent(string? text) => new("text/plain", text, null, null);

    private static async Task<KnowledgeContent> ReadFileAsync(IFormFile file, CancellationToken ct)
    {
        var name = Path.GetFileName(file.FileName.Replace('\\', '/'));
        if (string.IsNullOrWhiteSpace(name) || name.Length > 200 || name.Any(char.IsControl) ||
            file.Length is <= 0 or > KnowledgeSourceService.MaxPdfBytes)
            throw new KnowledgeSourceException(400, "Upload a named, non-empty file of at most 5 MiB.");

        var ext = Path.GetExtension(name).ToLowerInvariant();
        if (ext is not (".pdf" or ".txt" or ".md"))
            throw new KnowledgeSourceException(415, "Supported file formats are PDF, UTF-8 TXT and Markdown.");
        if (ext != ".pdf" && file.Length > 4L * KnowledgeSourceService.MaxTextLength + 3)
            throw new KnowledgeSourceException(400, "Text uploads exceed the text size limit.");
        using var buffer = new MemoryStream((int)file.Length);
        await file.CopyToAsync(buffer, ct);
        var bytes = buffer.ToArray();
        if (ext == ".pdf")
            return new KnowledgeContent("application/pdf", null, bytes, name);

        try
        {
            var content = Utf8.GetString(bytes).TrimStart('\uFEFF');
            if (content.Contains('\0'))
                throw new KnowledgeSourceException(415, "Upload a text file without binary bytes.");
            return new KnowledgeContent(ext == ".md" ? "text/markdown" : "text/plain", content, null, name);
        }
        catch (DecoderFallbackException)
        {
            throw new KnowledgeSourceException(415, "Text files must use UTF-8 encoding.");
        }
    }
}
