namespace SynTrace.Application.Contracts.Meetings;

public sealed record PublishedDraft(string JiraKey, string? Url, IReadOnlyList<string> SubtaskKeys,
    IReadOnlyList<string> FailedSubtasks);

/// <summary>Creates the Jira ticket for an approved draft of an approved meeting.</summary>
public interface IMeetingDraftPublisher
{
    Task<PublishedDraft> PublishAsync(string meetingId, string draftId, CancellationToken ct);
}
