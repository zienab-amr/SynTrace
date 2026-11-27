using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Application.Exceptions;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Services.Assistant;

namespace SynTrace.Infrastructure.Services.Meetings;

/// <summary>Tenant and permission boundary for the internal AI meeting API. AI owns the document and extraction state.</summary>
public sealed class MeetingGateway(
    ICurrentTenant tenant, ICurrentEmployee actor, IMeetingPermissionService permissionService,
    AssistantProjectAccess projectAccess, IHttpClientFactory clients, IOptions<AiServiceOptions> options)
    : IMeetingGateway
{
    private sealed record Context(string CompanyId, string EmployeeId, string[] Projects,
        string[] JiraKeys, IReadOnlySet<string> Grants);
    private sealed record Source(MeetingGatewayResult Result, string Status);
    private const int MaxText = 400_000;
    private const int MaxPdfBase64 = 14_000_000;

    public async Task<MeetingGatewayResult> CreateAsync(CreateMeetingRequest input, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        Require(ctx, MeetingPermission.Create);
        var project = ctx.Projects.FirstOrDefault(p => string.Equals(p, input.ProjectKey, StringComparison.OrdinalIgnoreCase))
            ?? throw new RequestFailureException(403, "Project is not accessible.");
        if (input.SourceType is not ("online" or "offline" or "note" or "pdf") ||
            input.Title?.Length > 300 || input.MeetingDate?.Length > 40 ||
            input.Text?.Length > MaxText || input.PdfBase64?.Length > MaxPdfBase64)
            throw new RequestFailureException(400, "Invalid meeting source or field length.");
        if (input.SourceType == "pdf")
        {
            if (string.IsNullOrWhiteSpace(input.PdfBase64) || !string.IsNullOrWhiteSpace(input.Text))
                throw new RequestFailureException(400, "A PDF source requires pdfBase64 only.");
        }
        else if (string.IsNullOrWhiteSpace(input.Text) || !string.IsNullOrWhiteSpace(input.PdfBase64))
            throw new RequestFailureException(400, "A text source requires text only.");
        if (input.Glossary is { } glossary && glossary.GetRawText().Length > 20_000)
            throw new RequestFailureException(400, "Glossary is too long.");

        return await SendAsync(HttpMethod.Post, "/meetings", new
        {
            companyId = ctx.CompanyId, allowedProjects = ctx.Projects,
            sourceId = Guid.NewGuid().ToString("D"), projectKey = project,
            sourceType = input.SourceType, title = input.Title, meetingDate = input.MeetingDate,
            text = input.Text, pdfBase64 = input.PdfBase64, createdBy = ctx.EmployeeId,
            glossary = input.Glossary
        }, ct);
    }

    public async Task<MeetingGatewayResult> GetAsync(string id, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        RequireReadPermission(ctx);
        var source = await ReadSourceAsync(ctx, id, ct);
        RequireRead(ctx, source.Status);
        return source.Result;
    }

    public async Task<MeetingGatewayResult> GetDocumentAsync(string id, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        RequireReadPermission(ctx);
        var source = await ReadSourceAsync(ctx, id, ct);
        RequireRead(ctx, source.Status);
        return await SendAsync(HttpMethod.Get, Path(id) + "/document" + Query(ctx), null, ct);
    }

    public async Task<MeetingGatewayResult> EditDocumentAsync(string id, EditMeetingDocumentRequest input, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        Require(ctx, MeetingPermission.Edit);
        Require(ctx, MeetingPermission.ReadPending);
        if (input.Text is null || input.Text.Length > MaxText)
            throw new RequestFailureException(400, "Invalid document length.");
        await RequirePendingAsync(ctx, id, ct);
        return await SendAsync(HttpMethod.Put, Path(id) + "/document", new
        {
            companyId = ctx.CompanyId, allowedProjects = ctx.Projects, text = input.Text, editedBy = ctx.EmployeeId
        }, ct);
    }

    public async Task<MeetingGatewayResult> RewriteDocumentAsync(string id, RewriteMeetingDocumentRequest input, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        Require(ctx, MeetingPermission.Edit);
        Require(ctx, MeetingPermission.ReadPending);
        Require(ctx, MeetingPermission.UseAgent);
        if (string.IsNullOrWhiteSpace(input.Instruction) || input.Instruction.Length > 2_000 ||
            (input.Part is { } part && part.GetRawText().Length > MaxText))
            throw new RequestFailureException(400, "Invalid rewrite instruction or part.");
        await RequirePendingAsync(ctx, id, ct);
        return await SendAsync(HttpMethod.Post, Path(id) + "/document/rewrite", new
        {
            companyId = ctx.CompanyId, allowedProjects = ctx.Projects,
            instruction = input.Instruction, part = input.Part
        }, ct);
    }

    public async Task<MeetingGatewayResult> ReviewAsync(string id, ReviewMeetingRequest input, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        Require(ctx, MeetingPermission.Approve);
        Require(ctx, MeetingPermission.ReadPending);
        var approve = input.Approve ?? [];
        var delete = input.Delete ?? [];
        var links = input.Links ?? new Dictionary<string, string[]>();
        if (approve.Count > 500 || delete.Count > 500 || links.Count > 500 ||
            approve.Concat(delete).Any(InvalidItemId) || approve.Intersect(delete, StringComparer.Ordinal).Any() ||
            links.Any(pair => InvalidItemId(pair.Key) || pair.Value is null || pair.Value.Length > 500 ||
                pair.Value.Any(key => !IsAllowedJiraKey(ctx, key))))
            throw new RequestFailureException(400, "Invalid review items or Jira links.");
        await RequirePendingAsync(ctx, id, ct);
        return await SendAsync(HttpMethod.Post, Path(id) + "/review", new
        {
            companyId = ctx.CompanyId, allowedProjects = ctx.Projects,
            reviewerId = ctx.EmployeeId, approve, delete, links
        }, ct);
    }

    public async Task<MeetingGatewayResult> GetPdfAsync(string id, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        Require(ctx, MeetingPermission.ReadApproved);
        Require(ctx, MeetingPermission.ExportPdf);
        var source = await ReadSourceAsync(ctx, id, ct);
        if (source.Status != "approved") throw new RequestFailureException(409, "Meeting must be approved first.");
        return await SendAsync(HttpMethod.Get, Path(id) + "/requirements.pdf" + Query(ctx), null, ct,
            fileName: $"requirements-{id}.pdf");
    }

    public async Task<MeetingGatewayResult> DeleteAsync(string id, CancellationToken ct)
    {
        var ctx = await GetContextAsync(ct);
        Require(ctx, MeetingPermission.Delete);
        Require(ctx, MeetingPermission.ReadPending);
        var source = await ReadSourceAsync(ctx, id, ct);
        if (source.Status == "approved")
            throw new RequestFailureException(409, "Approved meetings cannot be deleted by this endpoint.");
        return await SendAsync(HttpMethod.Delete, Path(id) + Query(ctx), null, ct);
    }

    private async Task<Context> GetContextAsync(CancellationToken ct)
    {
        if (!options.Value.EnableMeetingContract)
            throw new RequestFailureException(503, "The new meeting contract is not enabled.");
        var company = tenant.CompanyId;
        var employee = actor.EmployeeId;
        var grants = await permissionService.GetForEmployeeAsync(company, employee, ct);
        var scope = await projectAccess.GetScopeAsync(company, employee, ct);
        var projects = scope.MeetingProjectIds.ToArray();
        if (projects.Length == 0)
            throw new RequestFailureException(403, "No accessible projects are available.");
        return new Context(company, employee, projects, scope.JiraKeys.ToArray(), grants);
    }

    private static void Require(Context ctx, string permission)
    {
        if (!ctx.Grants.Contains(permission))
            throw new RequestFailureException(403, "Meeting permission is required.");
    }

    private static void RequireReadPermission(Context ctx)
    {
        if (!ctx.Grants.Contains(MeetingPermission.ReadApproved) &&
            !ctx.Grants.Contains(MeetingPermission.ReadPending))
            throw new RequestFailureException(403, "Meeting read permission is required.");
    }

    private static void RequireRead(Context ctx, string status) =>
        Require(ctx, status == "approved" ? MeetingPermission.ReadApproved : MeetingPermission.ReadPending);

    private async Task RequirePendingAsync(Context ctx, string id, CancellationToken ct)
    {
        if ((await ReadSourceAsync(ctx, id, ct)).Status != "pending_review")
            throw new RequestFailureException(409, "Meeting must be pending review.");
        // The AI service must enforce this condition atomically too; the preliminary GET is not a lock.
    }

    private async Task<Source> ReadSourceAsync(Context ctx, string id, CancellationToken ct)
    {
        var result = await SendAsync(HttpMethod.Get, Path(id) + Query(ctx), null, ct);
        try
        {
            using var doc = JsonDocument.Parse(result.Body);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object ||
                !root.TryGetProperty("sourceId", out var sourceId) || sourceId.ValueKind != JsonValueKind.String ||
                !string.Equals(sourceId.GetString(), id, StringComparison.Ordinal) ||
                !root.TryGetProperty("projectKey", out var project) || project.ValueKind != JsonValueKind.String ||
                !ctx.Projects.Contains(project.GetString(), StringComparer.OrdinalIgnoreCase))
                throw new RequestFailureException(404, "Meeting not found in accessible projects.");
            if (!root.TryGetProperty("status", out var status) || status.ValueKind != JsonValueKind.String ||
                status.GetString() is not ("processing" or "pending_review" or "approved" or "failed"))
                throw new RequestFailureException(503, "Invalid meeting state from AI service.");
            return new Source(result, status.GetString()!);
        }
        catch (JsonException)
        {
            throw new RequestFailureException(503, "Invalid meeting response from AI service.");
        }
    }

    private static bool InvalidItemId(string? value) => string.IsNullOrWhiteSpace(value) || value.Length > 200;
    private static bool IsAllowedJiraKey(Context ctx, string? key)
    {
        if (string.IsNullOrWhiteSpace(key) || key.Length > 100) return false;
        int separator = key.LastIndexOf('-');
        return separator > 0 && separator < key.Length - 1 &&
            ctx.JiraKeys.Contains(key[..separator], StringComparer.OrdinalIgnoreCase) &&
            key[(separator + 1)..].All(char.IsAsciiDigit);
    }

    private static string Path(string id)
    {
        if (string.IsNullOrWhiteSpace(id) || id.Length > 200 || id is "." or ".." ||
            !Regex.IsMatch(id, @"\A[A-Za-z0-9_.:-]+\z", RegexOptions.CultureInvariant))
            throw new RequestFailureException(400, "Invalid meeting id.");
        return "/meetings/" + Uri.EscapeDataString(id);
    }

    private static string Query(Context ctx) =>
        "?companyId=" + Uri.EscapeDataString(ctx.CompanyId) +
        "&allowedProjects=" + Uri.EscapeDataString(string.Join(",", ctx.Projects));

    private async Task<MeetingGatewayResult> SendAsync(HttpMethod method, string path, object? payload,
        CancellationToken ct, string? fileName = null)
    {
        var config = options.Value;
        if (string.IsNullOrWhiteSpace(config.BaseUrl) || string.IsNullOrWhiteSpace(config.ApiKey))
            throw new RequestFailureException(503, "AI service is not configured.");
        using var request = new HttpRequestMessage(method, config.BaseUrl.TrimEnd('/') + path);
        request.Headers.Add("X-Internal-Api-Key", config.ApiKey);
        request.Headers.Add("X-Correlation-Id", Guid.NewGuid().ToString("N"));
        if (payload is not null) request.Content = JsonContent.Create(payload);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(Math.Clamp(config.TimeoutSeconds, 1, 180)));
        try
        {
            using var client = clients.CreateClient(AssistantClient.HttpClientName);
            client.Timeout = Timeout.InfiniteTimeSpan;
            client.MaxResponseContentBufferSize = 24 * 1024 * 1024;
            using var response = await client.SendAsync(request, timeout.Token);
            var code = (int)response.StatusCode;
            if (!response.IsSuccessStatusCode)
                throw new RequestFailureException(code switch
                {
                    400 or 403 or 404 or 409 or 413 or 422 or 429 => code,
                    _ => 503
                }, code switch
                {
                    403 => "Meeting access denied.", 404 => "Meeting not found.",
                    409 => "Meeting state does not allow this operation.",
                    400 or 413 or 422 => "Meeting request rejected by AI service.",
                    429 => "AI service rate limit reached.", _ => "AI meeting service is unavailable."
                });
            if (code == 204) return new(code, [], "application/json");
            var media = response.Content.Headers.ContentType?.MediaType;
            var expected = fileName is null ? "application/json" : "application/pdf";
            if (!string.Equals(media, expected, StringComparison.OrdinalIgnoreCase))
                throw new RequestFailureException(503, "Unexpected AI response type.");
            var data = await response.Content.ReadAsByteArrayAsync(timeout.Token);
            return new(code, data, expected, fileName);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new RequestFailureException(503, "AI meeting service timed out; check the state before retrying.");
        }
        catch (HttpRequestException)
        {
            throw new RequestFailureException(503, "AI meeting service is unavailable.");
        }
    }
}
