using System.Text.Json;
using SynTrace.Contracts.IntegrationEvents.Jira;

namespace SynTrace.Application.Mapping;

public static class JiraWebhookEventMapper
{
    public static bool TryMapEventTypeJira(string? eventName, JsonElement payload, out JiraEventType eventType)
    {
        eventType = default;

        if (string.IsNullOrWhiteSpace(eventName))
            return false;

        if (eventName == "jira:version_deleted")
        {
            eventType = HasMergedTo(payload)
                ? JiraEventType.VersionMerged
                : JiraEventType.VersionDeleted;

            return true;
        }

        switch (eventName)
        {
            // Issue Events
            case "jira:issue_created":
                eventType = JiraEventType.IssueCreated;
                return true;

            case "jira:issue_updated":
                eventType = JiraEventType.IssueUpdated;
                return true;

            case "jira:issue_deleted":
                eventType = JiraEventType.IssueDeleted;
                return true;

            // Comment Events
            case "comment_created":
                eventType = JiraEventType.CommentCreated;
                return true;

            case "comment_updated":
                eventType = JiraEventType.CommentUpdated;
                return true;

            case "comment_deleted":
                eventType = JiraEventType.CommentDeleted;
                return true;

            // Sprint Events
            case "sprint_created":
                eventType = JiraEventType.SprintCreated;
                return true;

            case "sprint_updated":
                eventType = JiraEventType.SprintUpdated;
                return true;

            case "sprint_deleted":
                eventType = JiraEventType.SprintDeleted;
                return true;

            case "sprint_started":
                eventType = JiraEventType.SprintStarted;
                return true;

            case "sprint_closed":
                eventType = JiraEventType.SprintClosed;
                return true;

            // Version Events
            case "jira:version_released":
                eventType = JiraEventType.VersionReleased;
                return true;

            case "jira:version_unreleased":
                eventType = JiraEventType.VersionUnreleased;
                return true;

            case "jira:version_created":
                eventType = JiraEventType.VersionCreated;
                return true;

            case "jira:version_moved":
                eventType = JiraEventType.VersionMoved;
                return true;

            case "jira:version_updated":
                eventType = JiraEventType.VersionUpdated;
                return true;

            case "jira:version_merged":
                eventType = JiraEventType.VersionMerged;
                return true;

            // Worklog Events
            case "worklog_created":
                eventType = JiraEventType.WorklogCreated;
                return true;

            case "worklog_updated":
                eventType = JiraEventType.WorklogUpdated;
                return true;

            case "worklog_deleted":
                eventType = JiraEventType.WorklogDeleted;
                return true;

            // Issue Link Events
            case "issuelink_created":
                eventType = JiraEventType.IssueLinkCreated;
                return true;

            case "issuelink_deleted":
                eventType = JiraEventType.IssueLinkDeleted;
                return true;

            // Issue Type Events
            case "issuetype_created":
                eventType = JiraEventType.IssueTypeCreated;
                return true;

            case "issuetype_updated":
                eventType = JiraEventType.IssueTypeUpdated;
                return true;

            case "issuetype_deleted":
                eventType = JiraEventType.IssueTypeDeleted;
                return true;

            // Project Events
            case "project_created":
                eventType = JiraEventType.ProjectCreated;
                return true;

            case "project_updated":
                eventType = JiraEventType.ProjectUpdated;
                return true;

            case "project_deleted":
                eventType = JiraEventType.ProjectDeleted;
                return true;

            case "project_soft_deleted":
                eventType = JiraEventType.ProjectSoftDeleted;
                return true;

            case "project_restored_deleted":
                eventType = JiraEventType.ProjectRestoredDeleted;
                return true;

            case "project_archived":
                eventType = JiraEventType.ProjectArchived;
                return true;

            case "project_restored_archived":
                eventType = JiraEventType.ProjectRestoredArchived;
                return true;

            // User Events
            case "user_created":
                eventType = JiraEventType.UserCreated;
                return true;

            case "user_updated":
                eventType = JiraEventType.UserUpdated;
                return true;

            case "user_deleted":
                eventType = JiraEventType.UserDeleted;
                return true;

            // Board Events
            case "board_created":
                eventType = JiraEventType.BoardCreated;
                return true;

            case "board_updated":
                eventType = JiraEventType.BoardUpdated;
                return true;

            case "board_deleted":
                eventType = JiraEventType.BoardDeleted;
                return true;

            case "board_configuration_changed":
                eventType = JiraEventType.BoardConfigurationChanged;
                return true;

            default:
                return false;
        }
    }

    private static bool HasMergedTo(JsonElement payload)
    {
        // Support mergedTo at the root level.
        if (HasNonNullProperty(payload, "mergedTo"))
            return true;

        // Also support mergedTo inside a version object.
        return payload.ValueKind == JsonValueKind.Object
            && payload.TryGetProperty("version", out var version)
            && HasNonNullProperty(version, "mergedTo");
    }

    private static bool HasNonNullProperty(
        JsonElement element,
        string propertyName)
    {
        if (element.ValueKind != JsonValueKind.Object
            || !element.TryGetProperty(propertyName, out var value))
        {
            return false;
        }

        if (value.ValueKind is JsonValueKind.Null
            or JsonValueKind.Undefined)
        {
            return false;
        }

        if (value.ValueKind == JsonValueKind.String)
            return !string.IsNullOrWhiteSpace(value.GetString());

        return true;
    }
}