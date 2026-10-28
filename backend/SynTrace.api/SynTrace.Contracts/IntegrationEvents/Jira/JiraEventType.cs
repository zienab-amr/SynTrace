namespace SynTrace.Contracts.IntegrationEvents.Jira;

/// <summary>
/// Internal, source-independent event types used by SynTrace.
/// These names are NOT the webhook event names sent by Jira.
/// Keep the explicit values stable once events are persisted or sent to a broker.
/// </summary>
public enum JiraEventType
{
    IssueCreated = 1,
    IssueUpdated = 2,
    IssueDeleted = 3,

    CommentCreated = 4,
    CommentUpdated = 5,
    CommentDeleted = 6,

    SprintCreated = 7,
    SprintUpdated = 8,
    SprintDeleted = 9,
    SprintStarted = 10,
    SprintClosed = 11,

    VersionReleased = 12,
    VersionUnreleased = 13,
    VersionCreated = 14,
    VersionMoved = 15,
    VersionUpdated = 16,
    VersionMerged = 17,
    VersionDeleted = 18,

    WorklogCreated = 19,
    WorklogUpdated = 20,
    WorklogDeleted = 21,

    IssueLinkCreated = 22,
    IssueLinkDeleted = 23,

    IssueTypeCreated = 24,
    IssueTypeUpdated = 25,
    IssueTypeDeleted = 26,

    ProjectCreated = 27,
    ProjectUpdated = 28,
    ProjectDeleted = 29,
    ProjectSoftDeleted = 30,
    ProjectRestoredDeleted = 31,
    ProjectArchived = 32,
    ProjectRestoredArchived = 33,

    UserCreated = 34,
    UserUpdated = 35,
    UserDeleted = 36,

    BoardCreated = 37,
    BoardUpdated = 38,
    BoardDeleted = 39,
    BoardConfigurationChanged = 40
}
