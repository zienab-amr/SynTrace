namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class GitHubSyncOptions
{
    public const string SectionName = "GitHubSync";
    public bool Enabled { get; set; }
    public int ReconcileHours { get; set; } = 6;
    public int MaxCodeFileBytes { get; set; } = 65_536;
    public int MaxCodeFiles { get; set; } = 500;
    public int MaxCodeSnapshotBytes { get; set; } = 8_388_608;
    public int MaxTreeEntries { get; set; } = 100_000;
}
