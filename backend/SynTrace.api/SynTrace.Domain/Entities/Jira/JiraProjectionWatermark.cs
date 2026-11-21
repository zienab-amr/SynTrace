namespace SynTrace.Domain.Entities;

public enum JiraProjectionKind
{
    Issue,
    Project,
    Comment,
    Sprint
}

public sealed class JiraProjectionWatermark
{
    public string JiraConnectionId { get; set; } = string.Empty;
    public string CompanyId { get; set; } = string.Empty;
    public JiraProjectionKind Kind { get; set; }
    public string ExternalId { get; set; } = string.Empty;
    public DateTime SourceOccurredAtUtc { get; set; }
    public DateTime? LastDeletedAtUtc { get; set; }
    public bool IsDeleted { get; set; }
}
