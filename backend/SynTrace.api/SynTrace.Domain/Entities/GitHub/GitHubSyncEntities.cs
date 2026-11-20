namespace SynTrace.Domain.Entities.GitHub;

public sealed class GitHubRepositorySync
{
    public string BindingId { get; set; } = null!;
    public long RequestedVersion { get; set; } = 1;
    public long CompletedVersion { get; set; }
    public long RunningVersion { get; set; }
    public long ProducedVersion { get; set; }
    public string Phase { get; set; } = "start";
    public int NextPage { get; set; } = 1;
    public string? TargetHeadSha { get; set; }
    public string? LastIndexedHeadSha { get; set; }
    public string? LeaseToken { get; set; }
    public DateTime? LeaseUntilUtc { get; set; }
    public DateTime DueAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? LastSuccessAtUtc { get; set; }
    public string? LastFailure { get; set; }
    public int ConsecutiveFailures { get; set; }
    public bool Revoked { get; set; }
}

public sealed class GitHubSyncedItem
{
    public string BindingId { get; set; } = null!;
    public string Kind { get; set; } = null!;
    public string EntityId { get; set; } = null!;
    public string PayloadJson { get; set; } = null!;
    public long SourceVersion { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}

public sealed class GitHubDataOutbox
{
    public string BindingId { get; set; } = null!;
    public long SourceVersion { get; set; }
    public string CompanyId { get; set; } = null!;
    public string ProjectId { get; set; } = null!;
    public long InstallationId { get; set; }
    public long RepositoryId { get; set; }
    public string EventType { get; set; } = null!;
    public string EntityId { get; set; } = null!;
    public string PayloadJson { get; set; } = null!;
    public DateTime OccurredAtUtc { get; set; }
}
