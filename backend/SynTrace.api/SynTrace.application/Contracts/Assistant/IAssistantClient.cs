using SynTrace.Application.Contracts.Meetings;

namespace SynTrace.Application.Contracts.Assistant;

public sealed record AssistantLink(string Key, string Url);
public sealed record AssistantHistoryTurn(string Question, string Answer);
public sealed record AssistantAnswer(string Status, string Answer, IReadOnlyList<AssistantLink> Links, string CorrelationId)
{
    // Up to four short answers when the assistant asked one question back (shown as buttons).
    public IReadOnlyList<string>? Choices { get; init; }
    // Only when the message was about a meeting in this chat (live help, or which project).
    public System.Text.Json.JsonElement? Meeting { get; init; }
}
public enum AssistantFailure { None, BadRequest, Misconfigured, Unavailable, Cancelled }
public sealed record AssistantResult(AssistantAnswer? Answer, AssistantFailure Failure);
public sealed record AssistantProjectScope(IReadOnlyList<string> JiraKeys, IReadOnlyList<string> SynTraceProjectIds)
{
    public string? EmployeeDisplayName { get; init; }
    public MeetingAssistantPermissions? MeetingPermissions { get; init; }
    public IReadOnlyList<string> MeetingProjectIds => JiraKeys.Concat(SynTraceProjectIds)
        .Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
}

public interface IAssistantClient
{
    Task<AssistantResult> AskAsync(
        string question,
        string companyId,
        string employeeId,
        AssistantProjectScope scope,
        string correlationId,
        string? jiraAccountId,
        string conversationId,
        IReadOnlyList<AssistantHistoryTurn> history,
        IReadOnlyList<string> addedTo,
        IReadOnlyList<string> quotedExcerpts,
        bool clearAiMemory,
        CancellationToken cancellationToken,
        string? transcript = null,
        string? meetingDate = null);

    // Best-effort server-side cancellation of in-flight AI generation.
    Task CancelAsync(string correlationId, CancellationToken cancellationToken);
}
