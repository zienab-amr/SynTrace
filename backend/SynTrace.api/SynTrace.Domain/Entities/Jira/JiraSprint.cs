namespace SynTrace.Domain.Entities;

public class JiraSprint : ITenantOwned
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string CompanyId { get; set; } = string.Empty;
    public string ExternalId { get; set; } = string.Empty;
    public string? Name { get; set; }
    public string? State { get; set; }
    public string? BoardExternalId { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public DateTime? CompleteDate { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
