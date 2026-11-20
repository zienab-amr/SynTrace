namespace SynTrace.Domain.Entities.GitHub;

public sealed class GitHubConnection
{
    public string CompanyId { get; set; } = null!;
    public long InstallationId { get; set; }
    public long GitHubAccountId { get; set; }
    public string GitHubAccountLogin { get; set; } = null!;
    public string ConnectedByEmployeeId { get; set; } = null!;
    public bool IsActive { get; set; } = true;
    public bool IsSuspended { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // A null value is permitted only for installations the account itself owns.
    // Organizations are limited to the repositories the consenting actor administered.
    public string? VerifiedRepositoryIdsJson { get; set; }
}

public sealed class GitHubInstallationOwnership
{
    public long InstallationId { get; set; }
    public string CompanyId { get; set; } = null!;
}

public sealed class GitHubEmployeeIdentity
{
    public string CompanyId { get; set; } = null!;
    public string EmployeeId { get; set; } = null!;
    public long GitHubUserId { get; set; }
    public string GitHubLogin { get; set; } = null!;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class GitHubRepositoryBinding
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string CompanyId { get; set; } = null!;
    public string ProjectId { get; set; } = null!;
    public long InstallationId { get; set; }
    public long RepositoryId { get; set; }
    public string Owner { get; set; } = null!;
    public string Name { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public string? DefaultBranch { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
