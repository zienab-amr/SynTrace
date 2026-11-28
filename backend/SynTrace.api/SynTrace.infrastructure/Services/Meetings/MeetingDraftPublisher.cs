using System.Collections.Concurrent;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Integrations.Jira;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Services.Assistant;

namespace SynTrace.Infrastructure.Services.Meetings;

/// <summary>
/// Publishes a meeting draft to Jira with the company connection. The ticket carries the draft's
/// jiraLabel; the Jira webhook then brings it back to the AI, which marks the draft published.
/// </summary>
public sealed class MeetingDraftPublisher(
    IMeetingGateway meetings, IMeetingPermissionService permissionService, ICurrentTenant tenant,
    ICurrentEmployee actor, AssistantProjectAccess projectAccess, SynTraceDbContext db, JiraApiClient jira)
    : IMeetingDraftPublisher
{
    // One publish per draft at a time, so a double tap does not create two tickets.
    private static readonly ConcurrentDictionary<string, byte> InFlight = new(StringComparer.Ordinal);
    private const string MeetingLabel = "from-meeting";

    private sealed record Draft(string Title, string? Description, IReadOnlyList<string> Acceptance,
        IReadOnlyList<string> Subtasks, string Label);

    public async Task<PublishedDraft> PublishAsync(string meetingId, string draftId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(draftId) || draftId.Length > 200)
            throw new RequestFailureException(400, "Invalid draft id.");
        var company = tenant.CompanyId;
        var grants = await permissionService.GetForEmployeeAsync(company, actor.EmployeeId, ct);
        if (!grants.Contains(MeetingPermission.PublishJiraTasks) || !grants.Contains(MeetingPermission.ReadApproved))
            throw new RequestFailureException(403, "Meeting permission is required.");

        // The gateway checks the company, the project and the read permission.
        var meeting = await meetings.GetAsync(meetingId, ct);
        using var json = JsonDocument.Parse(meeting.Body);
        var root = json.RootElement;
        if (root.GetProperty("status").GetString() != "approved")
            throw new RequestFailureException(409, "Approve the meeting before publishing its drafts.");
        var draft = FindDraft(root, draftId);
        var jiraKey = await JiraProjectKeyAsync(company, root.GetProperty("projectKey").GetString()!, ct);
        var connection = await db.JiraConnections.AsNoTracking()
            .Where(c => c.CompanyId == company && c.status && c.JiraConnectionType == JiraConnectionType.Company)
            .Select(c => new { c.Id, c.SiteUrl })
            .FirstOrDefaultAsync(ct)
            ?? throw new RequestFailureException(409, "Connect the company to Jira before publishing.");

        var lockKey = company + "|" + draftId;
        if (!InFlight.TryAdd(lockKey, 0))
            throw new RequestFailureException(409, "This draft is already being published.");
        try
        {
            var (parentType, subtaskType) = await IssueTypesAsync(connection.Id, jiraKey, ct);
            var key = await CreateIssueAsync(connection.Id, new Dictionary<string, object?>
            {
                ["project"] = new { key = jiraKey },
                ["summary"] = Cut(draft.Title, 255),
                ["issuetype"] = new { id = parentType },
                ["labels"] = new[] { MeetingLabel, draft.Label },
                ["description"] = Document(draft.Description, draft.Acceptance)
            }, ct);

            var made = new List<string>();
            var failed = new List<string>();
            foreach (var title in draft.Subtasks)
            {
                if (subtaskType is null) { failed.Add(title); continue; }
                try
                {
                    made.Add(await CreateIssueAsync(connection.Id, new Dictionary<string, object?>
                    {
                        ["project"] = new { key = jiraKey },
                        ["parent"] = new { key },
                        ["summary"] = Cut(title, 255),
                        ["issuetype"] = new { id = subtaskType },
                        ["labels"] = new[] { MeetingLabel }
                    }, ct));
                }
                catch (RequestFailureException) { failed.Add(title); }
            }
            var site = connection.SiteUrl?.TrimEnd('/');
            return new PublishedDraft(key, string.IsNullOrEmpty(site) ? null : site + "/browse/" + key, made, failed);
        }
        finally { InFlight.TryRemove(lockKey, out _); }
    }

    private static Draft FindDraft(JsonElement meeting, string draftId)
    {
        foreach (var item in meeting.GetProperty("items").EnumerateArray())
        {
            if (!item.TryGetProperty("drafts", out var drafts) || drafts.ValueKind != JsonValueKind.Array) continue;
            foreach (var draft in drafts.EnumerateArray())
            {
                if (draft.GetProperty("id").GetString() != draftId) continue;
                if (item.TryGetProperty("needsReview", out var review) && review.ValueKind == JsonValueKind.True)
                    throw new RequestFailureException(409, "The requirement still needs review.");
                if (Text(draft, "jiraKey") is not null)
                    throw new RequestFailureException(409, "This draft is already on Jira.");
                if (Text(draft, "status") != "approved")
                    throw new RequestFailureException(409, "Approve the draft in the review before publishing it.");
                var label = Text(draft, "jiraLabel")
                    ?? throw new RequestFailureException(503, "The draft has no Jira label.");
                return new Draft(Text(draft, "title") ?? "Meeting requirement", Text(draft, "description"),
                    Strings(draft, "acceptance", null), Strings(draft, "subtasks", "title"), label);
            }
        }
        throw new RequestFailureException(404, "Draft not found in this meeting.");
    }

    private async Task<string> JiraProjectKeyAsync(string company, string projectKey, CancellationToken ct)
    {
        var scope = await projectAccess.GetScopeAsync(company, actor.EmployeeId, ct);
        var key = scope.JiraKeys.FirstOrDefault(k => string.Equals(k, projectKey, StringComparison.OrdinalIgnoreCase));
        if (key is not null) return key;
        // A meeting saved under the SynTrace project id: its linked Jira project.
        var linked = await db.Projects.IgnoreQueryFilters().AsNoTracking()
            .Where(p => p.CompanyId == company && p.ProjectId == projectKey && p.JiraProject != null)
            .Select(p => p.JiraProject!.Key)
            .FirstOrDefaultAsync(ct);
        return linked is not null && scope.JiraKeys.Contains(linked, StringComparer.OrdinalIgnoreCase)
            ? linked
            : throw new RequestFailureException(409, "This project is not linked to a Jira project you can access.");
    }

    private async Task<(string Parent, string? Subtask)> IssueTypesAsync(string connectionId, string projectKey,
        CancellationToken ct)
    {
        using var doc = await Jira(() => jira.SendAsync(connectionId, HttpMethod.Get,
            $"/rest/api/3/issue/createmeta/{Uri.EscapeDataString(projectKey)}/issuetypes?maxResults=50",
            cancellationToken: ct));
        var types = new List<(string Id, string Name, bool Subtask)>();
        if (doc is not null)
            foreach (var field in new[] { "issueTypes", "values" })
                if (doc.RootElement.TryGetProperty(field, out var list) && list.ValueKind == JsonValueKind.Array)
                    foreach (var t in list.EnumerateArray())
                        if (Text(t, "id") is { } id)
                            types.Add((id, Text(t, "name") ?? "", t.TryGetProperty("subtask", out var s) && s.ValueKind == JsonValueKind.True));
        var parents = types.Where(t => !t.Subtask).ToList();
        var parent = parents.FirstOrDefault(t => t.Name.Equals("Story", StringComparison.OrdinalIgnoreCase)).Id
            ?? parents.FirstOrDefault(t => t.Name.Equals("Task", StringComparison.OrdinalIgnoreCase)).Id
            ?? parents.FirstOrDefault().Id
            ?? throw new RequestFailureException(409, "The Jira project has no issue type to create the ticket.");
        return (parent, types.FirstOrDefault(t => t.Subtask).Id);
    }

    private async Task<string> CreateIssueAsync(string connectionId, Dictionary<string, object?> fields,
        CancellationToken ct)
    {
        using var doc = await Jira(() => jira.SendAsync(connectionId, HttpMethod.Post, "/rest/api/3/issue",
            new { fields }, ct));
        return (doc is null ? null : Text(doc.RootElement, "key"))
            ?? throw new RequestFailureException(503, "Jira did not return the new ticket.");
    }

    private static async Task<JsonDocument?> Jira(Func<Task<JsonDocument?>> call)
    {
        try { return await call(); }
        catch (HttpRequestException ex) when (ex.StatusCode is System.Net.HttpStatusCode.Forbidden)
        {
            throw new RequestFailureException(403, "The Jira connection may not create tickets in this project.");
        }
        catch (HttpRequestException ex) when (ex.StatusCode is System.Net.HttpStatusCode.BadRequest)
        {
            throw new RequestFailureException(422, "Jira rejected the ticket; check the project's required fields.");
        }
        catch (HttpRequestException)
        {
            throw new RequestFailureException(503, "Jira is unavailable.");
        }
        catch (InvalidOperationException)
        {
            throw new RequestFailureException(409, "Reconnect the company to Jira before publishing.");
        }
    }

    // Atlassian Document Format: the description, then the acceptance criteria as a list.
    private static object Document(string? description, IReadOnlyList<string> acceptance)
    {
        var content = new List<object>();
        foreach (var paragraph in (description ?? "").Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            content.Add(new { type = "paragraph", content = new[] { new { type = "text", text = Cut(paragraph, 5000) } } });
        if (acceptance.Count > 0)
        {
            content.Add(new { type = "heading", attrs = new { level = 3 },
                content = new[] { new { type = "text", text = "Acceptance criteria" } } });
            content.Add(new
            {
                type = "bulletList",
                content = acceptance.Select(a => new
                {
                    type = "listItem",
                    content = new[] { new { type = "paragraph", content = new[] { new { type = "text", text = Cut(a, 2000) } } } }
                }).ToArray()
            });
        }
        if (content.Count == 0)
            content.Add(new { type = "paragraph", content = new[] { new { type = "text", text = "From an approved meeting." } } });
        return new { type = "doc", version = 1, content };
    }

    private static string? Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String &&
        !string.IsNullOrWhiteSpace(value.GetString()) ? value.GetString() : null;

    // A list of strings, or of objects whose `field` is the string (subtasks are {title, tag, assignee}).
    private static IReadOnlyList<string> Strings(JsonElement element, string name, string? field)
    {
        if (!element.TryGetProperty(name, out var list) || list.ValueKind != JsonValueKind.Array) return [];
        var found = new List<string>();
        foreach (var entry in list.EnumerateArray())
        {
            var text = entry.ValueKind == JsonValueKind.String ? entry.GetString()
                : field is not null && entry.ValueKind == JsonValueKind.Object ? Text(entry, field) : null;
            if (!string.IsNullOrWhiteSpace(text)) found.Add(text.Trim());
        }
        return found.Take(20).ToList();
    }

    private static string Cut(string text, int max) => text.Length <= max ? text : text[..max];
}
