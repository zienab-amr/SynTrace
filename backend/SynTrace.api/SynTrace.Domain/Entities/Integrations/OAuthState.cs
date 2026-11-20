using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Entities.Integrations;

public sealed class OAuthState
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string StateHash { get; set; } = string.Empty;
    public IntegrationProvider Provider { get; set; }
    public OAuthStatePurpose Purpose { get; set; }
    public string CompanyId { get; set; } = string.Empty;
    public Company Company { get; set; } = null!;
    public string EmployeeId { get; set; } = string.Empty;
    public Employee Employee { get; set; } = null!;
    public string? EncryptedCodeVerifier { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? ConsumedAt { get; set; }
}
