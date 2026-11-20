using System.Text.Json.Serialization;

namespace SynTrace.Domain.Entities.Knowledge;

[JsonConverter(typeof(JsonStringEnumConverter<KnowledgeSourceKind>))]
public enum KnowledgeSourceKind { Documentation = 1, Requirements = 2, MeetingNotes = 3 }
[JsonConverter(typeof(JsonStringEnumConverter<KnowledgeMeetingMode>))]
public enum KnowledgeMeetingMode { Online = 1, InPerson = 2 }
[JsonConverter(typeof(JsonStringEnumConverter<KnowledgeSourceStatus>))]
public enum KnowledgeSourceStatus { PendingExtraction, ExtractionFailed, AwaitingReview, Published, Rejected }
[JsonConverter(typeof(JsonStringEnumConverter<KnowledgeEvidenceKind>))]
public enum KnowledgeEvidenceKind { Requirement = 1, Decision = 2, ActionItem = 3, OpenQuestion = 4, Blocker = 5 }
[JsonConverter(typeof(JsonStringEnumConverter<KnowledgeEvidenceDecision>))]
public enum KnowledgeEvidenceDecision { Pending, Approved, Rejected }

public sealed class KnowledgeSource
{
    public Guid Id { get; set; }
    public string CompanyId { get; set; } = null!;
    public string ClientId { get; set; } = null!;
    public string? ProjectId { get; set; }
    public string CreatedByEmployeeId { get; set; } = null!;
    public KnowledgeSourceKind Kind { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public int CurrentVersion { get; set; }
    public int? PublishedVersion { get; set; }
    public int Revision { get; set; }
    public bool Withdrawn { get; set; }
}

public sealed class KnowledgeSourceVersion
{
    public Guid SourceId { get; set; }
    public int Number { get; set; }
    public string Title { get; set; } = null!;
    public string? FileName { get; set; }
    public string MediaType { get; set; } = null!;
    public string? Text { get; set; }
    public byte[]? Pdf { get; set; }
    public KnowledgeMeetingMode? MeetingMode { get; set; }
    public DateTimeOffset? MeetingAtUtc { get; set; }
    public string CreatedByEmployeeId { get; set; } = null!;
    public DateTime CreatedAtUtc { get; set; }
    public KnowledgeSourceStatus Status { get; set; }
    public string? FailureCode { get; set; }
    public string? ReviewedByEmployeeId { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }
    public List<KnowledgeEvidence> Evidence { get; set; } = [];
}

public sealed class KnowledgeEvidence
{
    public Guid Id { get; set; }
    public Guid SourceId { get; set; }
    public int Version { get; set; }
    public KnowledgeEvidenceKind Kind { get; set; }
    public string Text { get; set; } = null!;
    public string Quote { get; set; } = null!;
    public int QuoteOffset { get; set; }
    public KnowledgeEvidenceDecision Decision { get; set; }
}

public sealed class KnowledgePublicationChange
{
    public long Id { get; set; }
    public string CompanyId { get; set; } = null!;
    public string ProjectId { get; set; } = null!;
    public Guid SourceId { get; set; }
    public int Version { get; set; }
    public bool Removed { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
