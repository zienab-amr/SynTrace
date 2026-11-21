using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/projects/{projectId}/github/activity")]
public sealed class GitHubProjectActivityController(
    SynTraceDbContext db, ICurrentTenant tenant, ICurrentEmployee employee,
    ProjectIntegrationAccess access) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(string projectId, [FromQuery] string kind = "pull_request",
        [FromQuery, Range(0, int.MaxValue)] int offset = 0, CancellationToken ct = default)
    {
        if (kind is not ("commit" or "pull_request"))
            return BadRequest(new { message = "Use kind=commit or kind=pull_request." });
        var companyId = tenant.CompanyId;
        var project = await access.ReadProjectAsync(companyId, employee.EmployeeId, projectId, ct);
        if (project is null)
            return NotFound();

        var source = await (from binding in db.Set<GitHubRepositoryBinding>().AsNoTracking()
            join connection in db.Set<GitHubConnection>() on binding.CompanyId equals connection.CompanyId
            join sync in db.Set<GitHubRepositorySync>() on binding.Id equals sync.BindingId
            where binding.CompanyId == companyId && binding.ProjectId == projectId && binding.IsActive
                && connection.InstallationId == binding.InstallationId && connection.IsActive && !connection.IsSuspended
                && !sync.Revoked
            select new
            {
                binding.Id, binding.RepositoryId, binding.FullName,
                sync.RequestedVersion, sync.CompletedVersion, sync.Phase,
                sync.LastSuccessAtUtc, sync.LastFailure, sync.LastIndexedHeadSha
            }).SingleOrDefaultAsync(ct);
        if (source is null)
            return NotFound(new { message = "No synchronized GitHub repository is available." });

        var rows = await db.Set<GitHubSyncedItem>().AsNoTracking()
            .Where(x => x.BindingId == source.Id && x.Kind == kind)
            .OrderByDescending(x => x.UpdatedAtUtc).ThenBy(x => x.EntityId)
            .Skip(offset).Take(50).Select(x => x.PayloadJson).ToListAsync(ct);
        var items = rows.Select(x =>
        {
            using var json = JsonDocument.Parse(x);
            var item = json.RootElement.Clone();
            return new ActivityItem(item, ReadJiraKeys(item), ReadActorId(item, "authorId"), ReadActorId(item, "mergedById"));
        }).ToList();

        var jiraCloud = await db.JiraConnections.AsNoTracking().Where(x => x.CompanyId == companyId &&
                x.JiraConnectionType == JiraConnectionType.Company && x.status)
            .Select(x => new { x.CloudId, x.SiteUrl }).SingleOrDefaultAsync(ct);
        var keys = items.SelectMany(x => x.JiraKeys).Distinct(StringComparer.Ordinal).ToArray();
        var jiraProject = project.JiraProjectId is null || jiraCloud is null ? null :
            await db.JiraProjects.AsNoTracking().Where(x => x.Id == project.JiraProjectId && x.CompanyId == companyId)
                .Select(x => x.ExternalId).SingleOrDefaultAsync(ct);
        var issues = jiraProject is null || keys.Length == 0 ? [] :
            await db.JiraIssues.AsNoTracking()
                .Where(x => x.CompanyId == companyId && x.ProjectExternalId == jiraProject && keys.Contains(x.Key))
                .Select(x => new IssueReference(x.Key, x.Status, x.Summary)).ToListAsync(ct);
        var byKey = issues.GroupBy(x => x.Key, StringComparer.Ordinal)
            .Where(x => x.Count() == 1).ToDictionary(x => x.Key, x => x.Single(), StringComparer.Ordinal);

        var actorIds = items.SelectMany(x => new[] { x.AuthorId, x.MergedById })
            .OfType<long>().Distinct().ToArray();
        var identities = new Dictionary<long, LinkedActor>();
        if (jiraCloud is not null && actorIds.Length > 0)
        {
            var linked = await (from gh in db.Set<GitHubEmployeeIdentity>().AsNoTracking()
                join jira in db.JiraConnections.AsNoTracking()
                    on new { gh.CompanyId, gh.EmployeeId }
                    equals new { jira.CompanyId, EmployeeId = jira.ConnectedByEmployeeId }
                where gh.CompanyId == companyId && actorIds.Contains(gh.GitHubUserId) && jira.status
                    && jira.CloudId == jiraCloud.CloudId && jira.JiraConnectionType == JiraConnectionType.Employee
                    && jira.JiraAccountId != ""
                    && !db.JiraConnections.Any(other => other.CompanyId == companyId && other.status &&
                        other.CloudId == jiraCloud.CloudId && other.JiraConnectionType == JiraConnectionType.Employee &&
                        other.JiraAccountId == jira.JiraAccountId && other.ConnectedByEmployeeId != gh.EmployeeId)
                select new LinkedActor(gh.GitHubUserId, gh.EmployeeId, jira.JiraAccountId)).ToListAsync(ct);
            identities = linked.GroupBy(x => x.GitHubUserId).Where(x => x.Count() == 1)
                .ToDictionary(x => x.Key, x => x.Single());
        }

        return Ok(new
        {
            source,
            items = items.Select(x => new
            {
                activity = x.Payload,
                jira = x.JiraKeys.Where(byKey.ContainsKey).Select(key =>
                {
                    var issue = byKey[key];
                    return new { issue.Key, issue.Status, issue.Summary, url = jiraCloud!.SiteUrl.TrimEnd('/') + "/browse/" + Uri.EscapeDataString(issue.Key) };
                }),
                unresolvedJiraKeys = x.JiraKeys.Where(key => !byKey.ContainsKey(key)),
                linkedAuthor = x.AuthorId is long author ? identities.GetValueOrDefault(author) : null,
                linkedMergedBy = x.MergedById is long merger ? identities.GetValueOrDefault(merger) : null
            }),
            nextOffset = rows.Count == 50 ? offset + (long)rows.Count : (long?)null
        });
    }

    private static string[] ReadJiraKeys(JsonElement item) =>
        item.TryGetProperty("jiraKeys", out var keys) && keys.ValueKind == JsonValueKind.Array
            ? keys.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.String)
                .Select(x => x.GetString()!).Distinct(StringComparer.Ordinal).Take(40).ToArray()
            : [];

    private static long? ReadActorId(JsonElement item, string property) =>
        item.TryGetProperty(property, out var id) && id.ValueKind == JsonValueKind.Number && id.TryGetInt64(out var value)
            ? value : null;

    private sealed record IssueReference(string Key, string? Status, string? Summary);
    private sealed record LinkedActor(long GitHubUserId, string EmployeeId, string JiraAccountId);
    private sealed record ActivityItem(JsonElement Payload, string[] JiraKeys, long? AuthorId, long? MergedById);
}
