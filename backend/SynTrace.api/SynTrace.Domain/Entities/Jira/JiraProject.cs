namespace SynTrace.Domain.Entities;

public class JiraProject : ITenantOwned
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string CompanyId { get; set; } = string.Empty;
    public string ExternalId { get; set; } = string.Empty;
    public string? Key { get; set; }
    public string? Name { get; set; }
    public string? ProjectTypeKey { get; set; }
    public string? LeadAccountId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
