using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Meetings;

namespace SynTrace.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/meetings")]
public sealed class MeetingsController(IMeetingGateway meetings) : ControllerBase
{
    [HttpPost]
    [RequestSizeLimit(16_000_000)]
    public async Task<IActionResult> Create(CreateMeetingRequest request, CancellationToken ct) =>
        ToAction(await meetings.CreateAsync(request, ct));

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(string id, CancellationToken ct) =>
        ToAction(await meetings.GetAsync(id, ct));

    [HttpGet("{id}/document")]
    public async Task<IActionResult> GetDocument(string id, CancellationToken ct) =>
        ToAction(await meetings.GetDocumentAsync(id, ct));

    [HttpPut("{id}/document")]
    public async Task<IActionResult> EditDocument(string id, EditMeetingDocumentRequest request, CancellationToken ct) =>
        ToAction(await meetings.EditDocumentAsync(id, request, ct));

    [HttpPost("{id}/document/rewrite")]
    public async Task<IActionResult> RewriteDocument(string id, RewriteMeetingDocumentRequest request, CancellationToken ct) =>
        ToAction(await meetings.RewriteDocumentAsync(id, request, ct));

    [HttpPost("{id}/review")]
    public async Task<IActionResult> Review(string id, ReviewMeetingRequest request, CancellationToken ct) =>
        ToAction(await meetings.ReviewAsync(id, request, ct));

    [HttpGet("{id}/requirements.pdf")]
    public async Task<IActionResult> GetPdf(string id, CancellationToken ct) =>
        ToAction(await meetings.GetPdfAsync(id, ct));

    [HttpGet("permissions")]
    public async Task<IActionResult> GetPermissions([FromServices] IMeetingPermissionService permissionService,
        [FromServices] ICurrentTenant tenant, [FromServices] ICurrentEmployee employee, CancellationToken ct)
    {
        var grants = await permissionService.GetForEmployeeAsync(tenant.CompanyId, employee.EmployeeId, ct);
        Response.Headers.CacheControl = "no-store";
        return Ok(new { permissions = grants.OrderBy(x => x, StringComparer.Ordinal),
            assistant = MeetingAssistantPermissions.From(grants) });
    }

    private IActionResult ToAction(MeetingGatewayResult response)
    {
        Response.Headers.CacheControl = "no-store";
        if (response.StatusCode == 204) return NoContent();
        if (response.FileName is not null)
            return File(response.Body, response.ContentType, response.FileName);
        return new ContentResult
        {
            StatusCode = response.StatusCode, ContentType = response.ContentType,
            Content = Encoding.UTF8.GetString(response.Body)
        };
    }
}
