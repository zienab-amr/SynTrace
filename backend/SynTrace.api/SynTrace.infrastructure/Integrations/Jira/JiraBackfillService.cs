using System.Data;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Application.Messaging;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.Serialization;
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
    private readonly IJiraEventPublisher _publisher;
    private readonly ILogger<JiraBackfillService> _logger;

    public JiraBackfillService(SynTraceDbContext db, JiraApiClient api, IJiraEventPublisher publisher, ILogger<JiraBackfillService> logger)
    {
        _db = db;
        _api = api;
        _publisher = publisher;
        _logger = logger;
    }

    public async Task RunAsync(string connectionId, CancellationToken ct)
    {
        var connection = await _db.JiraConnections.AsNoTracking()
            .Where(c => c.Id == connectionId && c.status && c.JiraConnectionType == JiraConnectionType.Company)
            .Select(c => new { c.CompanyId, c.CloudId, c.SiteUrl, c.AiImportCompletedAt })
            .SingleOrDefaultAsync(ct);

        if (connection is null)
        {
            _logger.LogWarning("Back-fill skipped: connection {ConnectionId} not found/inactive.", connectionId);
            return;
        }

        var companyId = connection.CompanyId;

        await SetStatusAsync(connectionId, JiraSyncStatus.Running, null, null, ct);
        _logger.LogInformation("Jira back-fill started for connection {ConnectionId}.", connectionId);

        try
        {
            await SyncUsersAsync(connectionId, companyId, ct);
            var projects = await SyncProjectsAsync(connectionId, companyId, ct);

            foreach (var (id, key) in projects)
                await SyncIssuesAsync(connectionId, companyId, id, key, ct);

            await SyncSprintsAsync(connectionId, companyId, ct);

            // Only the first import (or a manual sync): webhooks keep the AI current after that.
            if (connection.AiImportCompletedAt is null)
            {
                await SendImportToAiAsync(connectionId, companyId, connection.CloudId, connection.SiteUrl,
                    projects, ct);
                await _db.JiraConnections.Where(c => c.Id == connectionId && c.status)
                    .ExecuteUpdateAsync(u => u.SetProperty(c => c.AiImportCompletedAt, (DateTime?)DateTime.UtcNow), ct);
            }

            await SetStatusAsync(connectionId, JiraSyncStatus.Completed, DateTime.UtcNow, null, CancellationToken.None);
            _logger.LogInformation("Jira back-fill completed for connection {ConnectionId}.", connectionId);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Jira back-fill failed for connection {ConnectionId}.", connectionId);
            var msg = ex.Message.Length > 500 ? ex.Message[..500] : ex.Message;
            await SetStatusAsync(connectionId, JiraSyncStatus.Failed, null, msg, CancellationToken.None);
        }
    }

    // ---------------- full copy for the AI ----------------
    private async Task SendImportToAiAsync(
        string connectionId, string companyId, string cloudId, string siteUrl, List<(string Id, string Key)> projects, CancellationToken ct)
    {
        var scope = new JiraProjectionScope(_db, companyId, connectionId);
        async Task Publish(JiraEventType type, string entity, object payload)
        {
            await scope.RequireActiveAsync(ct);
            await _publisher.PublishAsync(new CanonicalJiraEvent
            {
                EventId = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{connectionId}|{type}|{entity}"))).ToLowerInvariant(),
                EventType = type,
                SourceEventName = "syntrace:import",
                CompanyId = companyId,
                JiraConnectionId = connectionId,
                CloudId = cloudId,
                SiteUrl = siteUrl,
                CorrelationId = connectionId,
                ReceivedAtUtc = DateTimeOffset.UtcNow,
                Payload = JsonSerializer.SerializeToElement(payload, payload.GetType(), JiraEventContractJson.Options)
            }, ct);
        }

        using (var fields = await _api.SendAsync(connectionId, HttpMethod.Get, "/rest/api/3/field", cancellationToken: ct))
        {
            var list = fields?.RootElement.Clone() ?? JsonSerializer.SerializeToElement(Array.Empty<object>());
            await Publish(JiraEventType.FieldCatalog, DateTime.UtcNow.Ticks.ToString(), new { fields = list });
        }

        var sent = 0;
        foreach (var (projectId, projectKey) in projects)
        {
            if (await scope.IsDeletedAsync(JiraProjectionKind.Project, projectId, ct))
                continue;

            string? nextToken = null;
            do
            {
                var jql = Uri.EscapeDataString($"project = \"{projectKey}\" ORDER BY created ASC");
                var path = $"/rest/api/3/search/jql?jql={jql}&maxResults=100&fields=updated";
                if (nextToken is not null) path += $"&nextPageToken={Uri.EscapeDataString(nextToken)}";
                using var page = await _api.SendAsync(connectionId, HttpMethod.Get, path, cancellationToken: ct);
                if (page is null) break;
                nextToken = page.RootElement.Str("nextPageToken");

                foreach (var reference in page.RootElement.Arr("issues")?.EnumerateArray().ToList() ?? new List<JsonElement>())
                {
                    if (reference.Str("id") is not { } id) continue;
                    var issue = await GetFullIssueAsync(connectionId, id, ct);
                    if (issue is null ||
                        await scope.IsDeletedAsync(JiraProjectionKind.Issue, id, ct) ||
                        await scope.IsDeletedAsync(JiraProjectionKind.Project, projectId, ct))
                        continue;
                    var updated = reference.Obj("fields")?.Str("updated");
                    await Publish(JiraEventType.IssueSnapshot, $"{id}|{updated}", issue);
                    sent++;
                }
            } while (nextToken is not null);
        }

        await Publish(JiraEventType.ImportCompleted, DateTime.UtcNow.Ticks.ToString(), new { issueCount = sent });
        _logger.LogInformation("Sent {Count} issues to the AI for connection {ConnectionId}.", sent, connectionId);
    }

    private async Task<JsonNode?> GetFullIssueAsync(string connectionId, string issueId, CancellationToken ct)
    {
        var id = Uri.EscapeDataString(issueId);
        JsonNode? issue;
        try
        {
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/api/3/issue/{id}?fields=*all&expand=names,changelog", cancellationToken: ct);
            issue = doc is null ? null : JsonNode.Parse(doc.RootElement.GetRawText());
        }
        catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }
        if (issue is null) return null;

        // Jira cuts long lists short inside an issue. The AI needs all of them.
        await CompleteListAsync(connectionId, issue["fields"]?["comment"], "comments", $"/rest/api/3/issue/{id}/comment", "comments", ct);
        await CompleteListAsync(connectionId, issue["fields"]?["worklog"], "worklogs", $"/rest/api/3/issue/{id}/worklog", "worklogs", ct);
        await CompleteListAsync(connectionId, issue["changelog"], "histories", $"/rest/api/3/issue/{id}/changelog", "values", ct);
        return issue;
    }

    private async Task CompleteListAsync(
        string connectionId, JsonNode? holder, string itemsName, string path, string pageItemsName, CancellationToken ct)
    {
        if (holder is not JsonObject container || container[itemsName] is not JsonArray items) return;
        var total = container["total"]?.GetValue<int>() ?? items.Count;
        if (total <= items.Count) return;

        var all = new JsonArray();
        var startAt = 0;
        while (true)
        {
            using var page = await _api.SendAsync(connectionId, HttpMethod.Get, $"{path}?startAt={startAt}&maxResults=100", cancellationToken: ct);
            var values = page?.RootElement.Arr(pageItemsName)?.EnumerateArray().ToList();
            if (values is null || values.Count == 0) break;
            foreach (var value in values) all.Add(JsonNode.Parse(value.GetRawText()));
            startAt += values.Count;
            if (startAt >= total) break;
        }
        container[itemsName] = all;
        container["total"] = all.Count;
    }

    // ---------------- users ----------------
    private async Task SyncUsersAsync(string connectionId, string companyId, CancellationToken ct)
    {
        var scope = new JiraProjectionScope(_db, companyId, connectionId);
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
                await using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
                await scope.RequireActiveAsync(ct);
                var ids = items.Select(i => i.Id!).ToList();
                var existing = await _db.JiraUsers.IgnoreQueryFilters()
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
                await tx.CommitAsync(ct);
                _db.ChangeTracker.Clear();
            }

            if (total == 0) break;
            startAt += total;
        }
    }

    // ---------------- projects ----------------
    private async Task<List<(string Id, string Key)>> SyncProjectsAsync(string connectionId, string companyId, CancellationToken ct)
    {
        var scope = new JiraProjectionScope(_db, companyId, connectionId);
        var result = new List<(string, string)>();
        var startAt = 0;

        while (true)
        {
            var observedAt = DateTime.UtcNow;
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get,
                $"/rest/api/3/project/search?startAt={startAt}&maxResults=50&expand=lead", cancellationToken: ct);
            if (doc is null) break;

            var values = doc.RootElement.Arr("values");
            var page = values?.EnumerateArray().ToList() ?? new List<JsonElement>();

            var ids = page.Select(p => p.Str("id")).OfType<string>().ToList();
            await using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await scope.RequireActiveAsync(ct);
            var blocked = await scope.BlockedSnapshotIdsAsync(JiraProjectionKind.Project, ids, observedAt, ct);
            var existing = await _db.JiraProjects.IgnoreQueryFilters()
                .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
                .ToDictionaryAsync(x => x.ExternalId, ct);

            foreach (var p in page)
            {
                var id = p.Str("id");
                var key = p.Str("key");
                if (id is null || key is null) continue;

                if (blocked.Contains(id))
                {
                    if (existing.TryGetValue(id, out var current) && current.Key is string currentKey)
                        result.Add((id, currentKey));
                    continue;
                }

                if (!existing.TryGetValue(id, out var project))
                {
                    project = new JiraProject { CompanyId = companyId, ExternalId = id };
                    _db.JiraProjects.Add(project);
                }
                project.Key = key;
                project.Name = p.Str("name");
                project.ProjectTypeKey = p.Str("projectTypeKey");
                project.LeadAccountId = p.Obj("lead")?.Str("accountId");
                project.UpdatedAt = DateTime.UtcNow;
                result.Add((id, key));
            }

            await _db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            _db.ChangeTracker.Clear();

            if (doc.RootElement.Bool("isLast") != false || page.Count == 0) break;
            startAt += page.Count;
        }
        return result;
    }

    // ---------------- issues (+ comments) ----------------
    private async Task SyncIssuesAsync(string connectionId, string companyId, string projectId, string projectKey, CancellationToken ct)
    {
        var scope = new JiraProjectionScope(_db, companyId, connectionId);
        string? nextToken = null;
        do
        {
            // Bounded JQL is required by the enhanced search endpoint.
            var jql = Uri.EscapeDataString($"project = \"{projectKey}\" ORDER BY created ASC");
            var path = $"/rest/api/3/search/jql?jql={jql}&maxResults=100&fields=summary,status,assignee,project,updated,comment";
            if (nextToken is not null) path += $"&nextPageToken={Uri.EscapeDataString(nextToken)}";

            var observedAt = DateTime.UtcNow;
            using var doc = await _api.SendAsync(connectionId, HttpMethod.Get, path, cancellationToken: ct);
            if (doc is null) break;

            var issues = doc.RootElement.Arr("issues")?.EnumerateArray().ToList() ?? [];
            nextToken = doc.RootElement.Str("nextPageToken");
            var ids = issues.Select(i => i.Str("id")).OfType<string>().ToList();
            var projectIds = issues.Select(i => i.Obj("fields")?.Obj("project")?.Str("id") ?? projectId)
                .Append(projectId).Distinct().ToList();
            var commentWork = new List<(string IssueId, string IssueKey, JsonElement Comment)>();
            var extraComments = new List<(string IssueId, string IssueKey, int StartAt)>();

            await using (var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct))
            {
                await scope.RequireActiveAsync(ct);
                var blockedProjects = await scope.BlockedSnapshotIdsAsync(JiraProjectionKind.Project, projectIds, observedAt, ct);
                if (blockedProjects.Contains(projectId)) return;
                var blockedIssues = await scope.BlockedSnapshotIdsAsync(JiraProjectionKind.Issue, ids, observedAt, ct);
                var existing = await _db.JiraIssues.IgnoreQueryFilters()
                    .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
                    .ToDictionaryAsync(x => x.ExternalId, ct);

                foreach (var i in issues)
                {
                    var id = i.Str("id");
                    var key = i.Str("key");
                    if (id is null || key is null || blockedIssues.Contains(id)) continue;

                    var fields = i.Obj("fields");
                    var fieldProject = fields?.Obj("project");
                    var actualProjectId = fieldProject?.Str("id") ?? projectId;
                    if (blockedProjects.Contains(actualProjectId)) continue;

                    var updated = fields?.Date("updated")?.UtcDateTime;
                    if (!existing.TryGetValue(id, out var issue))
                    {
                        issue = new JiraIssue { CompanyId = companyId, ExternalId = id };
                        _db.JiraIssues.Add(issue);
                        existing[id] = issue;
                    }
                    if (issue.SourceUpdatedAt is null || updated >= issue.SourceUpdatedAt)
                    {
                        issue.Key = key;
                        issue.ProjectExternalId = actualProjectId;
                        issue.ProjectKey = fieldProject?.Str("key") ?? projectKey;
                        issue.Summary = fields?.Str("summary");
                        issue.Status = fields?.Obj("status")?.Str("name");
                        issue.AssigneeAccountId = fields?.Obj("assignee")?.Str("accountId");
                        issue.SourceUpdatedAt = updated;
                        issue.UpdatedAt = DateTime.UtcNow;
                    }

                    if (fields?.Obj("comment") is not { } comments || comments.Arr("comments") is not { } embedded)
                        continue;
                    foreach (var comment in embedded.EnumerateArray())
                        commentWork.Add((id, key, comment));
                    if ((comments.Long("total") ?? 0) > embedded.GetArrayLength())
                        extraComments.Add((id, key, embedded.GetArrayLength()));
                }

                await _db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
                _db.ChangeTracker.Clear();
            }

            foreach (var (id, key, startAt) in extraComments)
                await FetchRemainingCommentsAsync(connectionId, id, key, startAt, commentWork, ct);
            await UpsertCommentsAsync(scope, companyId, commentWork, observedAt, ct);
        } while (nextToken is not null);
    }

    private async Task FetchRemainingCommentsAsync(
        string connectionId, string issueId, string issueKey, int startAt,
        List<(string, string, JsonElement)> sink, CancellationToken ct)
    {
        while (true)
        {
            try
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
            catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
            {
                break;
            }
        }
    }

    private async Task UpsertCommentsAsync(JiraProjectionScope scope, string companyId,
        List<(string IssueId, string IssueKey, JsonElement Comment)> work, DateTime observedAt, CancellationToken ct)
    {
        if (work.Count == 0) return;

        var ids = work.Select(w => w.Comment.Str("id")).OfType<string>().Distinct().ToList();
        var issueIds = work.Select(w => w.IssueId).Distinct().ToList();
        await using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await scope.RequireActiveAsync(ct);
        var blocked = await scope.BlockedSnapshotIdsAsync(JiraProjectionKind.Comment, ids, observedAt, ct);
        var parentProjects = await _db.JiraIssues.IgnoreQueryFilters()
            .Where(x => x.CompanyId == companyId && issueIds.Contains(x.ExternalId))
            .ToDictionaryAsync(x => x.ExternalId, x => x.ProjectExternalId, ct);
        var blockedProjects = await scope.BlockedSnapshotIdsAsync(JiraProjectionKind.Project,
            parentProjects.Values.OfType<string>().Distinct().ToList(), observedAt, ct);
        var existing = await _db.JiraComments.IgnoreQueryFilters()
            .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
            .ToDictionaryAsync(x => x.ExternalId, ct);

        foreach (var (issueId, issueKey, cm) in work)
        {
            var id = cm.Str("id");
            if (id is null || blocked.Contains(id) ||
                !parentProjects.TryGetValue(issueId, out var parentProject) ||
                (parentProject is not null && blockedProjects.Contains(parentProject)))
                continue;

            var updated = (cm.Date("updated") ?? cm.Date("created"))?.UtcDateTime;
            if (!existing.TryGetValue(id, out var comment))
            {
                comment = new JiraComment { CompanyId = companyId, ExternalId = id };
                _db.JiraComments.Add(comment);
                existing[id] = comment;
            }
            else if (comment.SourceUpdatedAt is { } have && (updated is null || updated < have))
            {
                continue;
            }

            comment.IssueExternalId = issueId;
            comment.IssueKey = issueKey;
            comment.AuthorAccountId = cm.Obj("author")?.Str("accountId");
            comment.BodyText = cm.TryGetProperty("body", out var body) ? JiraJson.AdfToText(body) : null;
            comment.SourceCreatedAt = cm.Date("created")?.UtcDateTime;
            comment.SourceUpdatedAt = updated;
            comment.UpdatedAt = DateTime.UtcNow;
        }
        await _db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        _db.ChangeTracker.Clear();
    }

    // ---------------- sprints ----------------
    private async Task SyncSprintsAsync(string connectionId, string companyId, CancellationToken ct)
    {
        var scope = new JiraProjectionScope(_db, companyId, connectionId);
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
                var observedAt = DateTime.UtcNow;
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

                    var ids = page.Select(s => s.Str("id")).OfType<string>().ToList();
                    await using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
                    await scope.RequireActiveAsync(ct);
                    var blocked = await scope.BlockedSnapshotIdsAsync(JiraProjectionKind.Sprint, ids, observedAt, ct);
                    var existing = await _db.JiraSprints.IgnoreQueryFilters()
                        .Where(x => x.CompanyId == companyId && ids.Contains(x.ExternalId))
                        .ToDictionaryAsync(x => x.ExternalId, ct);

                    foreach (var s in page)
                    {
                        var id = s.Str("id");
                        if (id is null || blocked.Contains(id)) continue;
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
                        sprint.UpdatedAt = DateTime.UtcNow;
                    }
                    await _db.SaveChangesAsync(ct);
                    await tx.CommitAsync(ct);
                    _db.ChangeTracker.Clear();

                    if (doc!.RootElement.Bool("isLast") != false) break;
                    sStart += page.Count;
                }
            }
        }
    }

    private Task SetStatusAsync(string connectionId, JiraSyncStatus status, DateTime? syncedAt, string? error, CancellationToken ct) =>
        _db.JiraConnections.Where(c => c.Id == connectionId && c.status)
            .ExecuteUpdateAsync(s => s
                .SetProperty(c => c.SyncStatus, status)
                .SetProperty(c => c.LastSyncError, error)
                .SetProperty(c => c.LastSyncedAt, c => syncedAt ?? c.LastSyncedAt), ct);
}
