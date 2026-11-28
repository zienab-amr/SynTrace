using System.Text.Json;

namespace SynTrace.Application.Contracts.Meetings;

// LinkedSourceId: a correction of an approved meeting (the AI links the new note to the original).
public sealed record CreateMeetingRequest(string ProjectKey, string SourceType, string? Title,
    string? MeetingDate, string? Text, string? PdfBase64, JsonElement? Glossary, string? LinkedSourceId = null);
public sealed record ReviewMeetingRequest(IReadOnlyList<string>? Approve, IReadOnlyList<string>? Delete,
    IReadOnlyDictionary<string, string[]>? Links);
public sealed record EditMeetingDocumentRequest(string Text);
public sealed record RewriteMeetingDocumentRequest(string Instruction, JsonElement? Part);
public sealed record EditRequirementRequest(string Text);
public sealed record StartLiveSessionRequest(string ProjectKey, string? Title);
public sealed record LiveAssistRequest(string? Transcript, string? Question, IReadOnlyList<string>? Dismiss);
public sealed record LiveWrapUpRequest(string Transcript);
public sealed record LiveEndRequest(string? Transcript, string? MeetingDate);
public sealed record MeetingGatewayResult(int StatusCode, byte[] Body, string ContentType, string? FileName = null);

public interface IMeetingGateway
{
    Task<MeetingGatewayResult> CreateAsync(CreateMeetingRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> GetAsync(string id, CancellationToken ct);
    Task<MeetingGatewayResult> GetDocumentAsync(string id, CancellationToken ct);
    Task<MeetingGatewayResult> EditDocumentAsync(string id, EditMeetingDocumentRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> RewriteDocumentAsync(string id, RewriteMeetingDocumentRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> ReviewAsync(string id, ReviewMeetingRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> GetPdfAsync(string id, CancellationToken ct);
    Task<MeetingGatewayResult> RetryAsync(string id, CancellationToken ct);
    Task<MeetingGatewayResult> DeleteAsync(string id, CancellationToken ct);
    Task<MeetingGatewayResult> ListAsync(string projectKey, string? status, CancellationToken ct);
    Task<MeetingGatewayResult> GetRequirementsAsync(string projectKey, string? query, CancellationToken ct);
    Task<MeetingGatewayResult> EditRequirementAsync(string requirementId, EditRequirementRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> GetOpenQuestionsAsync(string projectKey, CancellationToken ct);
    Task<MeetingGatewayResult> StartLiveSessionAsync(StartLiveSessionRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> GetLiveSessionAsync(string sessionId, CancellationToken ct);
    Task<MeetingGatewayResult> AssistLiveSessionAsync(string sessionId, LiveAssistRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> WrapUpLiveSessionAsync(string sessionId, LiveWrapUpRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> EndLiveSessionAsync(string sessionId, LiveEndRequest input, CancellationToken ct);
    Task<MeetingGatewayResult> DeleteLiveSessionAsync(string sessionId, CancellationToken ct);
}
