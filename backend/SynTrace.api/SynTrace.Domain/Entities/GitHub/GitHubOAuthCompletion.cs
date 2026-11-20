using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Entities.GitHub;

public sealed class GitHubOAuthCompletion
{
    public string ProofHash { get; set; } = null!;
    public string CompanyId { get; set; } = null!;
    public string EmployeeId { get; set; } = null!;
    public OAuthStatePurpose Purpose { get; set; }
    public long GitHubUserId { get; set; }
    public string GitHubLogin { get; set; } = null!;
    public string EligibleInstallationsJson { get; set; } = "[]";
    public DateTime ExpiresAt { get; set; }
}
