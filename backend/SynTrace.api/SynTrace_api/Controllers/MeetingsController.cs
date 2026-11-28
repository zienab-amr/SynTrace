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

    [HttpPost("{id}/retry")]
    public async Task<IActionResult> Retry(string id, CancellationToken ct) =>
        ToAction(await meetings.RetryAsync(id, ct));

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id, CancellationToken ct) =>
        ToAction(await meetings.DeleteAsync(id, ct));

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string projectKey, [FromQuery] string? status, CancellationToken ct) =>
        ToAction(await meetings.ListAsync(projectKey, status, ct));

    [HttpGet("projects/{projectKey}/requirements")]
    public async Task<IActionResult> GetRequirements(string projectKey, [FromQuery] string? q, CancellationToken ct) =>
        ToAction(await meetings.GetRequirementsAsync(projectKey, q, ct));

    [HttpPatch("requirements/{requirementId}")]
    public async Task<IActionResult> EditRequirement(string requirementId, EditRequirementRequest request,
        CancellationToken ct) =>
        ToAction(await meetings.EditRequirementAsync(requirementId, request, ct));

    [HttpGet("projects/{projectKey}/open-questions")]
    public async Task<IActionResult> GetOpenQuestions(string projectKey, CancellationToken ct) =>
        ToAction(await meetings.GetOpenQuestionsAsync(projectKey, ct));

    [HttpPost("live")]
    [RequestSizeLimit(1_000_000)]
    public async Task<IActionResult> StartLive(StartLiveSessionRequest request, CancellationToken ct) =>
        ToAction(await meetings.StartLiveSessionAsync(request, ct));

    [HttpGet("live/{sessionId}")]
    public async Task<IActionResult> GetLive(string sessionId, CancellationToken ct) =>
        ToAction(await meetings.GetLiveSessionAsync(sessionId, ct));

    [HttpPost("live/{sessionId}/assist")]
    [RequestSizeLimit(2_000_000)]
    public async Task<IActionResult> AssistLive(string sessionId, LiveAssistRequest request, CancellationToken ct) =>
        ToAction(await meetings.AssistLiveSessionAsync(sessionId, request, ct));

    [HttpPost("live/{sessionId}/wrap-up")]
    [RequestSizeLimit(2_000_000)]
    public async Task<IActionResult> WrapUpLive(string sessionId, LiveWrapUpRequest request, CancellationToken ct) =>
        ToAction(await meetings.WrapUpLiveSessionAsync(sessionId, request, ct));

    [HttpPost("live/{sessionId}/end")]
    [RequestSizeLimit(2_000_000)]
    public async Task<IActionResult> EndLive(string sessionId, LiveEndRequest request, CancellationToken ct) =>
        ToAction(await meetings.EndLiveSessionAsync(sessionId, request, ct));

    [HttpDelete("live/{sessionId}")]
    public async Task<IActionResult> DeleteLive(string sessionId, CancellationToken ct) =>
        ToAction(await meetings.DeleteLiveSessionAsync(sessionId, ct));

    [HttpPost("{id}/drafts/{draftId}/publish")]
    public async Task<IActionResult> PublishDraft(string id, string draftId,
        [FromServices] IMeetingDraftPublisher publisher, CancellationToken ct) =>
        Ok(await publisher.PublishAsync(id, draftId, ct));

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
