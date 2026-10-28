using System.Text.Json;
using SynTrace.Contracts.IntegrationEvents.Jira;

namespace SynTrace.Application.Integrations.Jira;

/// <summary>
/// Maps Jira's external webhook event name to SynTrace's internal event type.
/// This is event-name mapping only; it does not normalize the full payload.
/// </summary>
public static class JiraWebhookEventMapper
{
    public static bool TryMapEventTypeJira(
        string? eventName,
        JsonElement payload,
        out JiraEventType eventType)
    {
        eventType = default;
        if (string.IsNullOrWhiteSpace(eventName))
            return false;

        switch (eventName.Trim())
        {
            case "jira:issue_created": eventType = JiraEventType.IssueCreated; return true;
            case "jira:issue_updated": eventType = JiraEventType.IssueUpdated; return true;
            case "jira:issue_deleted": eventType = JiraEventType.IssueDeleted; return true;

            case "comment_created": eventType = JiraEventType.CommentCreated; return true;
            case "comment_updated": eventType = JiraEventType.CommentUpdated; return true;
            case "comment_deleted": eventType = JiraEventType.CommentDeleted; return true;

            case "sprint_created": eventType = JiraEventType.SprintCreated; return true;
            case "sprint_updated": eventType = JiraEventType.SprintUpdated; return true;
            case "sprint_deleted": eventType = JiraEventType.SprintDeleted; return true;
            case "sprint_started": eventType = JiraEventType.SprintStarted; return true;
            case "sprint_closed": eventType = JiraEventType.SprintClosed; return true;

            case "jira:version_released": eventType = JiraEventType.VersionReleased; return true;
            case "jira:version_unreleased": eventType = JiraEventType.VersionUnreleased; return true;
            case "jira:version_created": eventType = JiraEventType.VersionCreated; return true;
            case "jira:version_moved": eventType = JiraEventType.VersionMoved; return true;
            case "jira:version_updated": eventType = JiraEventType.VersionUpdated; return true;
            case "jira:version_deleted":
                eventType = HasMergedTo(payload)
                    ? JiraEventType.VersionMerged
                    : JiraEventType.VersionDeleted;
                return true;

            case "worklog_created": eventType = JiraEventType.WorklogCreated; return true;
            case "worklog_updated": eventType = JiraEventType.WorklogUpdated; return true;
            case "worklog_deleted": eventType = JiraEventType.WorklogDeleted; return true;

            case "issuelink_created": eventType = JiraEventType.IssueLinkCreated; return true;
            case "issuelink_deleted": eventType = JiraEventType.IssueLinkDeleted; return true;

            case "issuetype_created": eventType = JiraEventType.IssueTypeCreated; return true;
            case "issuetype_updated": eventType = JiraEventType.IssueTypeUpdated; return true;
            case "issuetype_deleted": eventType = JiraEventType.IssueTypeDeleted; return true;

            case "project_created": eventType = JiraEventType.ProjectCreated; return true;
            case "project_updated": eventType = JiraEventType.ProjectUpdated; return true;
            case "project_deleted": eventType = JiraEventType.ProjectDeleted; return true;
            case "project_soft_deleted": eventType = JiraEventType.ProjectSoftDeleted; return true;
            case "project_restored_deleted": eventType = JiraEventType.ProjectRestoredDeleted; return true;
            case "project_archived": eventType = JiraEventType.ProjectArchived; return true;
            case "project_restored_archived": eventType = JiraEventType.ProjectRestoredArchived; return true;

            case "user_created": eventType = JiraEventType.UserCreated; return true;
            case "user_updated": eventType = JiraEventType.UserUpdated; return true;
            case "user_deleted": eventType = JiraEventType.UserDeleted; return true;

            case "board_created": eventType = JiraEventType.BoardCreated; return true;
            case "board_updated": eventType = JiraEventType.BoardUpdated; return true;
            case "board_deleted": eventType = JiraEventType.BoardDeleted; return true;
            case "board_configuration_changed": eventType = JiraEventType.BoardConfigurationChanged; return true;

            default:
                return false;
        }
    }

    private static bool HasMergedTo(JsonElement payload)
    {
        if (payload.ValueKind != JsonValueKind.Object)
            return false;

        if (HasNonEmptyProperty(payload, "mergedTo"))
            return true;

        return payload.TryGetProperty("version", out var version)
            && version.ValueKind == JsonValueKind.Object
            && HasNonEmptyProperty(version, "mergedTo");
    }

    private static bool HasNonEmptyProperty(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property))
            return false;

        return property.ValueKind switch
        {
            JsonValueKind.String => !string.IsNullOrWhiteSpace(property.GetString()),
            JsonValueKind.Number => property.GetRawText() != "0",
            JsonValueKind.Object => true,
            _ => false
        };
    }
}
