using System.Text.Json;

namespace SynTrace.Application.Contracts.Meetings;

public sealed record CreateMeetingRequest(string ProjectKey, string SourceType, string? Title,
    string? MeetingDate, string? Text, string? PdfBase64, JsonElement? Glossary);
public sealed record ReviewMeetingRequest(IReadOnlyList<string>? Approve, IReadOnlyList<string>? Delete,
    IReadOnlyDictionary<string, string[]>? Links);
public sealed record EditMeetingDocumentRequest(string Text);
public sealed record RewriteMeetingDocumentRequest(string Instruction, JsonElement? Part);
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
    Task<MeetingGatewayResult> DeleteAsync(string id, CancellationToken ct);
}
