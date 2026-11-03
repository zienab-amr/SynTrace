using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Enums;
using SynTrace.Domain.Enums.Jira;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

/// <summary>
/// Pulls the HISTORICAL data (users, projects, issues, comments, sprints) through the Jira REST API.
/// Idempotent upserts + "newer wins" rule, so it is safe to run while webhooks are flowing and safe to re-run.
/// Sprints are only available this way (dynamic webhooks do not deliver sprint events).
/// </summary>
public sealed class JiraBackfillService : IJiraBackfillService
{
    private readonly SynTraceDbContext _db;
    private readonly JiraApiClient _api;
    private readonly ILogger<JiraBackfillService> _logger;

    public JiraBackfillService(SynTraceDbContext db, JiraApiClient api, ILogger<JiraBackfillService> logger)
    {
        _db = db;
        _api = api;
        _logger = logger;
    }

    public async Task RunAsync(string connectionId, CancellationToken ct)
    {
        var companyId = await _db.JiraConnections.AsNoTracking()
            .Where(c => c.Id == connectionId && c.status)
            .Select(c => c.CompanyId)
            .SingleOrDefaultAsync(ct);

        if (companyId is null)
        {
            _logger.LogWarning("Back-fill skipped: connection {ConnectionId} not found/inactive.", connectionId);
            return;
        }

        await SetStatusAsync(connectionId, JiraSyncStatus.Running, null, null, ct);
        _logger.LogInformation("Jira back-fill started for connection {ConnectionId}.", connectionId);

        try
        {
            await SyncUsersAsync(connectionId, companyId, ct);
            var projects = await SyncProjectsAsync(connectionId, companyId, ct);

            foreach (var (_, key) in projects)
                await SyncIssuesAsync(connectionId, companyId, key, ct);

            await SyncSprintsAsync(connectionId, companyId, ct);

            await SetStatusAsync(connectionId, JiraSyncStatus.Completed, DateTime.UtcNow, null, CancellationToken.None);
            _logger.LogInformation("Jira back-fill completed for connection {ConnectionId}.", connectionId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Jira back-fill failed for connection {ConnectionId}.", connectionId);
            var msg = ex.Message.Length > 500 ? ex.Message[..500] : ex.Message;
            await SetStatusAsync(connectionId, JiraSyncStatus.Failed, null, msg, CancellationToken.None);
        }
    }

    // ---------------- users ----------------
    private async Task SyncUsersAsync(string connectionId, string companyId, CancellationToken ct)
    {
        var startAt = 0;
        while (true)
        {
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/api/3/users/search?startAt={startAt}&maxResults=100", cancellationToken: ct);
            if (doc is null || doc.RootElement.ValueKind != JsonValueKind.Array) break;

            var items = doc.RootElement.EnumerateArray()
                .Where(u => u.Str("accountType") is null or "atlassian")   // skip app/customer accounts
                .Select(u => (Id: u.Str("accountId"), Name: u.Str("displayName"), Active: u.Bool("active")))
                .Where(u => u.Id is not null)
                .ToList();

            var total = doc.RootElement.GetArrayLength();
            if (items.Count > 0)
            {
                var ids = items.Select(i => i.Id!).ToList();
                var existing = await _db.JiraUsers
                    .Where(x => x.CompanyId == companyId && ids.Contains(x.AccountId))
                    .ToDictionaryAsync(x => x.AccountId, ct);

                foreach (var i in items)
                {
                    if (!existing.TryGetValue(i.Id!, out var user))
                    {
                        user = new JiraUser { CompanyId = companyId, AccountId = i.Id! };
                        _db.JiraUsers.Add(user);
                    }
                    user.DisplayName = i.Name;
                    user.Active = i.Active;
                    user.UpdatedAt = DateTime.UtcNow;
                }
                await _db.SaveChangesAsync(ct);
                _db.ChangeTracker.Clear();
            }

            if (total == 0) break;
            startAt += total;
        }
    }

    // ---------------- projects ----------------
    private async Task<List<(string Id, string Key)>> SyncProjectsAsync(string connectionId, string companyId, CancellationToken ct)
    {
        var result = new List<(string, string)>();
        var startAt = 0;

        while (true)
        {
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/api/3/project/search?startAt={startAt}&maxResults=50&expand=lead", cancellationToken: ct);
            if (doc is null) break;

            var values = doc.RootElement.Arr("values");
            var page = values?.EnumerateArray().ToList() ?? new List<JsonElement>();

            var ids = page.Select(p => p.Str("id")).Where(x => x is not null).Select(x => x!).ToList();
            var existing = await _db.JiraProjects
                .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
                .ToDictionaryAsync(x => x.ExternalId, ct);

            foreach (var p in page)
            {
                var id = p.Str("id");
                var key = p.Str("key");
                if (id is null || key is null) continue;

                if (!existing.TryGetValue(id, out var project))
                {
                    project = new JiraProject { CompanyId = companyId, ExternalId = id };
                    _db.JiraProjects.Add(project);
                }
                project.Key = key;
                project.Name = p.Str("name");
                project.ProjectTypeKey = p.Str("projectTypeKey");
                project.LeadAccountId = p.Obj("lead")?.Str("accountId");
                project.IsDeleted = false;
                project.UpdatedAt = DateTime.UtcNow;
                result.Add((id, key));
            }

            await _db.SaveChangesAsync(ct);
            _db.ChangeTracker.Clear();

            if (doc.RootElement.Bool("isLast") != false || page.Count == 0) break;
            startAt += page.Count;
        }
        return result;
    }

    // ---------------- issues (+ comments) ----------------
    private async Task SyncIssuesAsync(string connectionId, string companyId, string projectKey, CancellationToken ct)
    {
        string? nextToken = null;
        do
        {
            // Bounded JQL (project = X) - required by the enhanced search endpoint.
            var jql = Uri.EscapeDataString($"project = \"{projectKey}\" ORDER BY created ASC");
            var path = $"/rest/api/3/search/jql?jql={jql}&maxResults=100&fields=summary,status,assignee,project,updated,comment";
            if (nextToken is not null) path += $"&nextPageToken={Uri.EscapeDataString(nextToken)}";

            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get, path, cancellationToken: ct);
            if (doc is null) break;

            var issues = doc.RootElement.Arr("issues")?.EnumerateArray().ToList() ?? new List<JsonElement>();
            nextToken = doc.RootElement.Str("nextPageToken");

            var ids = issues.Select(i => i.Str("id")).Where(x => x is not null).Select(x => x!).ToList();
            var existing = await _db.JiraIssues
                .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
                .ToDictionaryAsync(x => x.ExternalId, ct);

            var commentWork = new List<(string IssueId, string IssueKey, JsonElement Comment)>();

            foreach (var i in issues)
            {
                var id = i.Str("id");
                var key = i.Str("key");
                if (id is null || key is null) continue;

                var fields = i.Obj("fields");
                var updated = fields?.Date("updated")?.UtcDateTime;

                if (!existing.TryGetValue(id, out var issue))
                {
                    issue = new JiraIssue { CompanyId = companyId, ExternalId = id };
                    _db.JiraIssues.Add(issue);
                }
                else if (issue.SourceUpdatedAt is { } have && updated is { } incoming && incoming < have)
                {
                    continue;   // a newer webhook already updated it
                }

                issue.Key = key;
                issue.ProjectExternalId = fields?.Obj("project")?.Str("id");
                issue.ProjectKey = fields?.Obj("project")?.Str("key");
                issue.Summary = fields?.Str("summary");
                issue.Status = fields?.Obj("status")?.Str("name");
                issue.AssigneeAccountId = fields?.Obj("assignee")?.Str("accountId");
                issue.IsDeleted = false;
                issue.SourceUpdatedAt = updated ?? issue.SourceUpdatedAt;
                issue.UpdatedAt = DateTime.UtcNow;

                if (fields?.Obj("comment") is { } c && c.Arr("comments") is { } embedded)
                {
                    foreach (var cm in embedded.EnumerateArray()) commentWork.Add((id, key, cm));

                    // Search results embed only the first page of comments; pull the rest.
                    var total = c.Long("total") ?? 0;
                    var have2 = embedded.GetArrayLength();
                    if (total > have2)
                        await FetchRemainingCommentsAsync(connectionId, id, key, have2, commentWork, ct);
                }
            }

            await _db.SaveChangesAsync(ct);
            await UpsertCommentsAsync(companyId, commentWork, ct);
            _db.ChangeTracker.Clear();

        } while (nextToken is not null);
    }

    private async Task FetchRemainingCommentsAsync(
        string connectionId, string issueId, string issueKey, int startAt,
        List<(string, string, JsonElement)> sink, CancellationToken ct)
    {
        while (true)
        {
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/api/3/issue/{Uri.EscapeDataString(issueId)}/comment?startAt={startAt}&maxResults=100", cancellationToken: ct);
            var list = doc?.RootElement.Arr("comments")?.EnumerateArray().Select(x => x.Clone()).ToList();
            if (list is null || list.Count == 0) break;

            foreach (var c in list) sink.Add((issueId, issueKey, c));
            startAt += list.Count;

            var total = doc!.RootElement.Long("total") ?? 0;
            if (startAt >= total) break;
        }
    }

    private async Task UpsertCommentsAsync(string companyId, List<(string IssueId, string IssueKey, JsonElement Comment)> work, CancellationToken ct)
    {
        if (work.Count == 0) return;

        var ids = work.Select(w => w.Comment.Str("id")).Where(x => x is not null).Select(x => x!).Distinct().ToList();
        var existing = await _db.JiraComments
            .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
            .ToDictionaryAsync(x => x.ExternalId, ct);

        foreach (var (issueId, issueKey, cm) in work)
        {
            var id = cm.Str("id");
            if (id is null) continue;

            var updated = cm.Date("updated")?.UtcDateTime;
            if (!existing.TryGetValue(id, out var comment))
            {
                comment = new JiraComment { CompanyId = companyId, ExternalId = id };
                _db.JiraComments.Add(comment);
                existing[id] = comment;
            }
            else if (comment.SourceUpdatedAt is { } have && updated is { } incoming && incoming < have)
            {
                continue;
            }

            comment.IssueExternalId = issueId;
            comment.IssueKey = issueKey;
            comment.AuthorAccountId = cm.Obj("author")?.Str("accountId");
            comment.BodyText = cm.TryGetProperty("body", out var body) ? JiraJson.AdfToText(body) : null;
            comment.SourceCreatedAt = cm.Date("created")?.UtcDateTime;
            comment.SourceUpdatedAt = updated;
            comment.IsDeleted = false;
            comment.UpdatedAt = DateTime.UtcNow;
        }
        await _db.SaveChangesAsync(ct);
    }

    // ---------------- sprints ----------------
    private async Task SyncSprintsAsync(string connectionId, string companyId, CancellationToken ct)
    {
        var boards = new List<string>();
        var startAt = 0;
        while (true)
        {
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/agile/1.0/board?startAt={startAt}&maxResults=50", cancellationToken: ct);
            var page = doc?.RootElement.Arr("values")?.EnumerateArray().Select(b => b.Str("id")).Where(x => x is not null).Select(x => x!).ToList();
            if (page is null || page.Count == 0) break;
            boards.AddRange(page);
            if (doc!.RootElement.Bool("isLast") != false) break;
            startAt += page.Count;
        }

        foreach (var boardId in boards)
        {
            var sStart = 0;
            while (true)
            {
                JsonDocument? doc;
                try
                {
                    doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                        $"/rest/agile/1.0/board/{boardId}/sprint?startAt={sStart}&maxResults=50", cancellationToken: ct);
                }
                catch (HttpRequestException ex) when (ex.StatusCode == System.Net.HttpStatusCode.BadRequest)
                {
                    break;   // Kanban boards don't support sprints
                }

                using (doc)
                {
                    var page = doc?.RootElement.Arr("values")?.EnumerateArray().ToList();
                    if (page is null || page.Count == 0) break;

                    var ids = page.Select(s => s.Str("id")).Where(x => x is not null).Select(x => x!).ToList();
                    var existing = await _db.JiraSprints
                        .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
                        .ToDictionaryAsync(x => x.ExternalId, ct);

                    foreach (var s in page)
                    {
                        var id = s.Str("id");
                        if (id is null) continue;
                        if (!existing.TryGetValue(id, out var sprint))
                        {
                            sprint = new JiraSprint { CompanyId = companyId, ExternalId = id };
                            _db.JiraSprints.Add(sprint);
                        }
                        sprint.Name = s.Str("name");
                        sprint.State = s.Str("state");
                        sprint.BoardExternalId = s.Str("originBoardId") ?? boardId;
                        sprint.StartDate = s.Date("startDate")?.UtcDateTime;
                        sprint.EndDate = s.Date("endDate")?.UtcDateTime;
                        sprint.CompleteDate = s.Date("completeDate")?.UtcDateTime;
                        sprint.IsDeleted = false;
                        sprint.UpdatedAt = DateTime.UtcNow;
                    }
                    await _db.SaveChangesAsync(ct);
                    _db.ChangeTracker.Clear();

                    if (doc!.RootElement.Bool("isLast") != false) break;
                    sStart += page.Count;
                }
            }
        }
    }

    private Task SetStatusAsync(string connectionId, JiraSyncStatus status, DateTime? syncedAt, string? error, CancellationToken ct) =>
        _db.JiraConnections.Where(c => c.Id == connectionId)
            .ExecuteUpdateAsync(s => s
                .SetProperty(c => c.SyncStatus, status)
                .SetProperty(c => c.LastSyncError, error)
                .SetProperty(c => c.LastSyncedAt, c => syncedAt ?? c.LastSyncedAt), ct);
}
