namespace SynTrace.Domain.Entities;

public class JiraComment : ITenantOwned
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string CompanyId { get; set; } = string.Empty;
    public string ExternalId { get; set; } = string.Empty;
    public string IssueExternalId { get; set; } = string.Empty;
    public string? IssueKey { get; set; }
    public string? AuthorAccountId { get; set; }
    public string? BodyText { get; set; }
    public DateTime? SourceCreatedAt { get; set; }
    public DateTime? SourceUpdatedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
