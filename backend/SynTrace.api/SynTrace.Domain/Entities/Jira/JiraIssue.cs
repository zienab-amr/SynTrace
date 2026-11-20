namespace SynTrace.Domain.Entities;

public class JiraIssue : ITenantOwned
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string CompanyId { get; set; } = string.Empty;
    public string ExternalId { get; set; } = string.Empty;
    public string Key { get; set; } = string.Empty;
    public string? ProjectExternalId { get; set; }
    public string? ProjectKey { get; set; }
    public string? Summary { get; set; }
    public string? Status { get; set; }
    public string? AssigneeAccountId { get; set; }
    public DateTime? SourceUpdatedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
