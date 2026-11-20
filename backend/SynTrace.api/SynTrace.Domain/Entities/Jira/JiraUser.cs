namespace SynTrace.Domain.Entities;

public class JiraUser : ITenantOwned
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string CompanyId { get; set; } = string.Empty;
    public string AccountId { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
    public bool? Active { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
