using System.ComponentModel.DataAnnotations;
using SynTrace.Domain.Entities.Knowledge;

namespace SynTrace.Application.Contracts.Knowledge;

public sealed class CreateKnowledgeSourceRequest
{
    [Required, StringLength(450)] public string ClientId { get; init; } = "";
    [StringLength(450)] public string? ProjectId { get; init; }
    public KnowledgeSourceKind Kind { get; init; }
    [Required, StringLength(200)] public string Title { get; init; } = "";
    [StringLength(256_000)] public string? Text { get; init; }
    public KnowledgeMeetingMode? MeetingMode { get; init; }
    public DateTimeOffset? MeetingAt { get; init; }
}

public sealed class AddKnowledgeVersionRequest
{
    [Range(1, int.MaxValue)] public int ExpectedVersion { get; init; }
    [Required, StringLength(200)] public string Title { get; init; } = "";
    [StringLength(256_000)] public string? Text { get; init; }
    public KnowledgeMeetingMode? MeetingMode { get; init; }
    public DateTimeOffset? MeetingAt { get; init; }
}

public sealed record KnowledgeContent(string MediaType, string? Text, byte[]? Pdf, string? FileName);
public sealed record KnowledgeSourceSummary(Guid Id, string ClientId, string? ProjectId, KnowledgeSourceKind Kind,
    string Title, int Version, int? PublishedVersion, KnowledgeSourceStatus Status);
public sealed record KnowledgeEvidenceView(Guid Id, KnowledgeEvidenceKind Kind, string Text, string Quote,
    int QuoteOffset, KnowledgeEvidenceDecision Decision);
public sealed record KnowledgeSourceView(KnowledgeSourceSummary Source, KnowledgeMeetingMode? MeetingMode,
    DateTimeOffset? MeetingAt, string? FileName, string? SourceText, IReadOnlyList<KnowledgeEvidenceView> Evidence,
    string? FailureCode);
public sealed record KnowledgeExtractionJob(Guid Id, int Version, string ClientId, string? ProjectId,
    KnowledgeSourceKind Kind, string Title, string MediaType, string? Text, string? FileName);
public sealed record KnowledgeEvidenceInput(KnowledgeEvidenceKind Kind,
    [Required, StringLength(2000)] string Text, [Required, StringLength(4000)] string Quote);
public sealed record KnowledgeExtractionRequest(
    [MaxLength(100)] IReadOnlyList<KnowledgeEvidenceInput>? Items,
    [StringLength(256_000)] string? ExtractedText,
    [StringLength(30)] string? FailureCode);
public sealed record KnowledgeEvidenceReview(Guid Id, bool Approve);
public sealed record KnowledgeReviewRequest([Required, MaxLength(100)] IReadOnlyList<KnowledgeEvidenceReview> Decisions, bool Publish);
public sealed record KnowledgeProjectLinkRequest([Required, StringLength(450)] string ProjectId);
public sealed record KnowledgeChange(long Cursor, Guid SourceId, int Version, string ProjectId, bool Removed);

public sealed class KnowledgeSourceException(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
}
