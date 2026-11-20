namespace SynTrace.Application.Contracts.Integrations.GitHub;

public enum GitHubConnectMode
{
    InstallCompany,
    ExistingCompanyInstallation,
    EmployeeIdentity
}

public sealed record GitHubConnectResponse(string Url);
public sealed record GitHubCallbackResponse(string Status, string? CompletionId);
public sealed record GitHubInstallationOption(long InstallationId, long AccountId, string AccountLogin, string AccountType, int? RepositoryCount);
public sealed record GitHubPendingConnection(string Kind, string GitHubLogin, IReadOnlyList<GitHubInstallationOption> Installations);
public sealed record GitHubRepositoryOption(long RepositoryId, string Owner, string Name, string FullName, string? DefaultBranch, bool IsPrivate);
public sealed record GitHubCompanyStatus(bool Connected, long? InstallationId, string? AccountLogin, bool Suspended);
public sealed record GitHubEmployeeStatus(bool Connected, long? GitHubUserId, string? GitHubLogin);
public sealed record GitHubProjectStatus(string ProjectId, string? BindingId, long? RepositoryId, string? FullName, string? DefaultBranch, string SyncStatus, DateTime? LastSuccessAtUtc);

public interface IGitHubOAuthService
{
    Task<GitHubConnectResponse> StartAsync(GitHubConnectMode mode, CancellationToken cancellationToken);
    Task<GitHubCallbackResponse> CallbackAsync(string state, string? code, string? setupAction, CancellationToken cancellationToken);
    Task<GitHubPendingConnection> PendingAsync(string completionId, CancellationToken cancellationToken);
    Task CompleteAsync(string completionId, long? installationId, CancellationToken cancellationToken);
    Task<GitHubCompanyStatus> CompanyStatusAsync(CancellationToken cancellationToken);
    Task<GitHubEmployeeStatus> EmployeeStatusAsync(CancellationToken cancellationToken);
    Task DisconnectCompanyAsync(CancellationToken cancellationToken);
    Task DisconnectEmployeeAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<GitHubRepositoryOption>> RepositoriesAsync(CancellationToken cancellationToken);
    Task<GitHubProjectStatus> ProjectStatusAsync(string projectId, CancellationToken cancellationToken);
    Task<GitHubProjectStatus> MapRepositoryAsync(string projectId, long repositoryId, CancellationToken cancellationToken);
    Task RequestProjectSyncAsync(string projectId, CancellationToken cancellationToken);
    Task UnmapRepositoryAsync(string projectId, CancellationToken cancellationToken);
}

public sealed class GitHubIntegrationException(string message, int statusCode) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}
