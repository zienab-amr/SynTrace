using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.IntegrationEvents.Jira.Payloads;
using SynTrace.Contracts.Serialization;

namespace SynTrace.Infrastructure.Integrations.Jira;

public sealed class JiraWebhookNormalizer
{
    private static readonly Dictionary<string, JiraEventType> EventMap = new(StringComparer.Ordinal)
    {
        ["jira:issue_created"] = JiraEventType.IssueCreated,
        ["jira:issue_updated"] = JiraEventType.IssueUpdated,
        ["jira:issue_deleted"] = JiraEventType.IssueDeleted,
        ["comment_created"] = JiraEventType.CommentCreated,
        ["comment_updated"] = JiraEventType.CommentUpdated,
        ["comment_deleted"] = JiraEventType.CommentDeleted,
        // Not deliverable through dynamic (OAuth) webhooks, but mapped so admin-registered webhooks also work.
        ["sprint_created"] = JiraEventType.SprintCreated,
        ["sprint_updated"] = JiraEventType.SprintUpdated,
        ["sprint_deleted"] = JiraEventType.SprintDeleted,
        ["sprint_started"] = JiraEventType.SprintStarted,
        ["sprint_closed"] = JiraEventType.SprintClosed
    };

    public CanonicalJiraEvent? Normalize(
        JsonElement root,
        string companyId,
        string connectionId,
        string correlationId,
        DateTimeOffset receivedAtUtc)
    {
        if (root.ValueKind != JsonValueKind.Object) return null;

        var sourceName = root.Str("webhookEvent");
        if (sourceName is null || !EventMap.TryGetValue(sourceName, out var type)) return null;

        DateTimeOffset? occurred = root.Long("timestamp") is { } ms
            ? DateTimeOffset.FromUnixTimeMilliseconds(ms)
            : null;

        object payload;
        string entityId;

        switch (type)
        {
            case JiraEventType.IssueCreated:
            case JiraEventType.IssueDeleted:
            {
                var p = BuildIssue(root, occurred);
                if (p is null) return null;
                payload = p; entityId = p.IssueId;
                break;
            }
            case JiraEventType.IssueUpdated:
            {
                var p = BuildIssueUpdated(root, occurred);
                if (p is null) return null;
                payload = p; entityId = p.IssueId;
                break;
            }
            case JiraEventType.CommentCreated:
            case JiraEventType.CommentUpdated:
            case JiraEventType.CommentDeleted:
            {
                var p = BuildComment(root);
                if (p is null) return null;
                payload = p; entityId = p.CommentId;
                break;
            }
            case JiraEventType.SprintCreated:
            case JiraEventType.SprintUpdated:
            case JiraEventType.SprintDeleted:
            case JiraEventType.SprintStarted:
            case JiraEventType.SprintClosed:
            {
                var p = BuildSprint(root);
                if (p is null) return null;
                payload = p; entityId = p.SprintId;
                break;
            }
            default:
                return null;
        }

        var changelogId = root.Obj("changelog")?.Str("id");
        var raw = $"{connectionId}|{sourceName}|{entityId}|{root.Str("timestamp")}|{changelogId}";
        var eventId = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(raw))).ToLowerInvariant();

        return new CanonicalJiraEvent
        {
            EventId = eventId,
            EventType = type,
            SchemaVersion = 1,
            SourceEventName = sourceName,
            CompanyId = companyId,
            JiraConnectionId = connectionId,
            CorrelationId = correlationId,
            OccurredAtUtc = occurred,
            ReceivedAtUtc = receivedAtUtc,
            Payload = JsonSerializer.SerializeToElement(payload, payload.GetType(), JiraEventContractJson.Options)
        };
    }

    private static JiraIssuePayload? BuildIssue(JsonElement root, DateTimeOffset? occurred)
    {
        if (root.Obj("issue") is not { } issue) return null;
        var id = issue.Str("id");
        var key = issue.Str("key");
        if (id is null || key is null) return null;

        var fields = issue.Obj("fields");
        return new JiraIssuePayload
        {
            IssueId = id,
            IssueKey = key,
            ProjectId = fields?.Obj("project")?.Str("id"),
            ProjectKey = fields?.Obj("project")?.Str("key"),
            Summary = fields?.Str("summary"),
            Status = fields?.Obj("status")?.Str("name"),
            AssigneeAccountId = fields?.Obj("assignee")?.Str("accountId"),
            SourceUpdatedAtUtc = fields?.Date("updated") ?? occurred
        };
    }

    private static JiraIssueUpdatedPayload? BuildIssueUpdated(JsonElement root, DateTimeOffset? occurred)
    {
        var basic = BuildIssue(root, occurred);
        if (basic is null) return null;

        var changes = new List<JiraFieldChange>();
        if (root.Obj("changelog")?.Arr("items") is { } items)
        {
            foreach (var item in items.EnumerateArray())
            {
                var field = item.Str("field");
                if (field is null) continue;

                // People fields: keep ids (accountId). Everything else: human-readable strings (e.g. status name).
                var useIds = field is "assignee" or "reporter";
                changes.Add(new JiraFieldChange(
                    field,
                    useIds ? item.Str("from") : item.Str("fromString") ?? item.Str("from"),
                    useIds ? item.Str("to") : item.Str("toString") ?? item.Str("to")));
            }
        }

        return new JiraIssueUpdatedPayload
        {
            IssueId = basic.IssueId,
            IssueKey = basic.IssueKey,
            ProjectId = basic.ProjectId,
            ProjectKey = basic.ProjectKey,
            Summary = basic.Summary,
            Status = basic.Status,
            AssigneeAccountId = basic.AssigneeAccountId,
            SourceUpdatedAtUtc = basic.SourceUpdatedAtUtc,
            Changes = changes
        };
    }

    private static JiraCommentPayload? BuildComment(JsonElement root)
    {
        if (root.Obj("comment") is not { } comment) return null;
        var id = comment.Str("id");
        var issueId = root.Obj("issue")?.Str("id") ?? comment.Str("issueId");
        if (id is null || issueId is null) return null;

        string? text = null;
        if (comment.TryGetProperty("body", out var body))
            text = JiraJson.AdfToText(body);

        return new JiraCommentPayload
        {
            CommentId = id,
            IssueId = issueId,
            IssueKey = root.Obj("issue")?.Str("key"),
            AuthorAccountId = comment.Obj("author")?.Str("accountId"),
            BodyText = text,
            CreatedAtUtc = comment.Date("created"),
            UpdatedAtUtc = comment.Date("updated")
        };
    }

    private static JiraSprintPayload? BuildSprint(JsonElement root)
    {
        if (root.Obj("sprint") is not { } sprint) return null;
        var id = sprint.Str("id");
        if (id is null) return null;

        return new JiraSprintPayload
        {
            SprintId = id,
            Name = sprint.Str("name"),
            State = sprint.Str("state"),
            BoardId = sprint.Str("originBoardId"),
            StartDateUtc = sprint.Date("startDate"),
            EndDateUtc = sprint.Date("endDate"),
            CompleteDateUtc = sprint.Date("completeDate")
        };
    }
}
