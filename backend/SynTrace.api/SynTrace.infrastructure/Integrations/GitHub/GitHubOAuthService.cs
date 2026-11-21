using System.Data;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Integrations.GitHub;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Domain.Enums;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class GitHubOAuthService(
    SynTraceDbContext db,
    IOAuthStateRepository states,
    ICurrentTenant tenant,
    ICurrentEmployee employee,
    ProjectIntegrationAccess access,
    GitHubApiClient github,
    IGitHubSyncTrigger sync,
    IOptions<GitHubOAuthOptions> options) : IGitHubOAuthService
{
    public async Task<GitHubConnectResponse> StartAsync(GitHubConnectMode mode, CancellationToken ct)
    {
        var config = ValidOAuthOptions();
        var company = tenant.CompanyId;
        var actor = employee.EmployeeId;
        var purpose = mode == GitHubConnectMode.EmployeeIdentity ? OAuthStatePurpose.Employee : OAuthStatePurpose.Company;
        await EnsureActorAsync(company, actor, purpose, ct);

        var installation = mode == GitHubConnectMode.InstallCompany;
        var verifier = installation ? null : GitHubApiClient.Base64Url(RandomNumberGenerator.GetBytes(32));
        var state = await states.CreateAsync(IntegrationProvider.GitHub, purpose, company, actor, verifier, ct);

        if (installation)
        {
            var installUrl = $"https://github.com/apps/{Uri.EscapeDataString(config.AppSlug)}/installations/new";
            return new GitHubConnectResponse(QueryHelpers.AddQueryString(installUrl, "state", state));
        }

        var challenge = GitHubApiClient.Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier!)));
        return new GitHubConnectResponse(QueryHelpers.AddQueryString("https://github.com/login/oauth/authorize",
            new Dictionary<string, string?>
            {
                ["client_id"] = config.ClientId,
                ["redirect_uri"] = config.RedirectUri,
                ["state"] = state,
                ["code_challenge"] = challenge,
                ["code_challenge_method"] = "S256",
                ["prompt"] = "select_account"
            }));
    }

    public async Task<GitHubCallbackResponse> CallbackAsync(string state, string? code, string? setupAction, CancellationToken ct)
    {
        var config = ValidOAuthOptions();
        var flow = await states.TryConsumeAsync(state, IntegrationProvider.GitHub, cancellationToken: ct);
        if (flow is null)
            throw new GitHubIntegrationException("The GitHub linking request expired or has already been used.", 400);
        await EnsureActorAsync(flow.CompanyId, flow.EmployeeId, flow.Purpose, ct);

        if (flow.Purpose == OAuthStatePurpose.Company && setupAction == "request" && string.IsNullOrWhiteSpace(code))
            return new GitHubCallbackResponse("awaiting-approval", null);
        if (string.IsNullOrWhiteSpace(code) || code.Length > 1024)
            throw new GitHubIntegrationException("GitHub did not return an authorization code.", 400);

        var userToken = await github.ExchangeUserCodeAsync(code, flow.CodeVerifier, ct);
        var user = await github.GetAsync<GitHubAccount>("/user", userToken, ct);
        if (user.Id <= 0 || !string.Equals(user.Type, "User", StringComparison.Ordinal) || string.IsNullOrWhiteSpace(user.Login))
            throw new GitHubIntegrationException("GitHub did not identify an eligible user account.", 403);

        IReadOnlyList<VerifiedInstallation> installations = [];
        if (flow.Purpose == OAuthStatePurpose.Company)
        {
            installations = await EligibleInstallationsAsync(config.AppId, userToken, user.Id, ct);
            if (installations.Count == 0)
                return new GitHubCallbackResponse("no-eligible-installations", null);
        }

        var proof = GitHubApiClient.Base64Url(RandomNumberGenerator.GetBytes(32));
        var now = DateTime.UtcNow;
        await db.Set<GitHubOAuthCompletion>().Where(x => x.ExpiresAt <= now).ExecuteDeleteAsync(ct);
        db.Set<GitHubOAuthCompletion>().Add(new GitHubOAuthCompletion
        {
            ProofHash = Hash(proof),
            CompanyId = flow.CompanyId,
            EmployeeId = flow.EmployeeId,
            Purpose = flow.Purpose,
            GitHubUserId = user.Id,
            GitHubLogin = user.Login,
            EligibleInstallationsJson = JsonSerializer.Serialize(installations),
            ExpiresAt = now.AddMinutes(5)
        });
        await db.SaveChangesAsync(ct);
        return new GitHubCallbackResponse("confirm", proof);
    }

    public async Task<GitHubPendingConnection> PendingAsync(string completionId, CancellationToken ct)
    {
        var pending = await ReadPendingAsync(completionId, ct);
        return new GitHubPendingConnection(
            pending.Purpose == OAuthStatePurpose.Company ? "company" : "employee",
            pending.GitHubLogin,
            ReadOptions(pending).Select(i => new GitHubInstallationOption(
                i.Id, i.AccountId, i.AccountLogin, i.AccountType, i.VerifiedRepositoryIds?.Count)).ToArray());
    }

    public async Task CompleteAsync(string completionId, long? installationId, CancellationToken ct)
    {
        var pending = await ReadPendingAsync(completionId, ct);
        VerifiedInstallation? choice = null;
        if (pending.Purpose == OAuthStatePurpose.Company)
        {
            choice = ReadOptions(pending).SingleOrDefault(x => x.Id == installationId)
                ?? throw new GitHubIntegrationException("Choose a GitHub installation from the verified selection.", 400);
            var current = await github.GetInstallationAsync(choice.Id, ct);
            if (current.AppId != ValidOAuthOptions().AppId || current.Account.Id != choice.AccountId || current.SuspendedAt is not null)
                throw new GitHubIntegrationException("This GitHub installation is no longer available.", 409);
            choice = choice with { AccountLogin = current.Account.Login };
        }
        else if (installationId is not null)
        {
            throw new GitHubIntegrationException("Employee links do not accept an installation ID.", 400);
        }

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var now = DateTime.UtcNow;
        await EnsureActorAsync(pending.CompanyId, pending.EmployeeId, pending.Purpose, ct);
        var consumed = await db.Set<GitHubOAuthCompletion>()
            .Where(x => x.ProofHash == pending.ProofHash && x.CompanyId == pending.CompanyId &&
                x.EmployeeId == pending.EmployeeId && x.ExpiresAt > now)
            .ExecuteDeleteAsync(ct);
        if (consumed != 1)
            throw new GitHubIntegrationException("The confirmation expired or has already been used.", 410);

        if (choice is not null)
            await ApplyCompanyConnectionAsync(pending, choice, now, ct);
        else
            await ApplyEmployeeConnectionAsync(pending, now, ct);

        await SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
    }

    public async Task<GitHubCompanyStatus> CompanyStatusAsync(CancellationToken ct)
    {
        await EnsureActorAsync(tenant.CompanyId, employee.EmployeeId, OAuthStatePurpose.Company, ct);
        var connection = await db.Set<GitHubConnection>().AsNoTracking()
            .SingleOrDefaultAsync(x => x.CompanyId == tenant.CompanyId, ct);
        return new GitHubCompanyStatus(connection is { IsActive: true, IsSuspended: false },
            connection?.InstallationId, connection?.GitHubAccountLogin, connection?.IsSuspended == true);
    }

    public async Task<GitHubEmployeeStatus> EmployeeStatusAsync(CancellationToken ct)
    {
        await EnsureActorAsync(tenant.CompanyId, employee.EmployeeId, OAuthStatePurpose.Employee, ct);
        var link = await db.Set<GitHubEmployeeIdentity>().AsNoTracking()
            .SingleOrDefaultAsync(x => x.CompanyId == tenant.CompanyId && x.EmployeeId == employee.EmployeeId, ct);
        return new GitHubEmployeeStatus(link is not null, link?.GitHubUserId, link?.GitHubLogin);
    }

    public async Task DisconnectCompanyAsync(CancellationToken ct)
    {
        var company = tenant.CompanyId;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await EnsureActorAsync(company, employee.EmployeeId, OAuthStatePurpose.Company, ct);
        var connection = await db.Set<GitHubConnection>().SingleOrDefaultAsync(x => x.CompanyId == company, ct);
        if (connection is null)
            return;

        var now = DateTime.UtcNow;
        connection.IsActive = false;
        connection.IsSuspended = false;
        connection.UpdatedAt = now;
        await db.Set<GitHubRepositoryBinding>()
            .Where(x => x.CompanyId == company && x.InstallationId == connection.InstallationId && x.IsActive)
            .ExecuteUpdateAsync(set => set.SetProperty(x => x.IsActive, false).SetProperty(x => x.UpdatedAt, now), ct);
        await SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
    }

    public async Task DisconnectEmployeeAsync(CancellationToken ct)
    {
        var company = tenant.CompanyId;
        var actor = employee.EmployeeId;
        await EnsureActorAsync(company, actor, OAuthStatePurpose.Employee, ct);
        await db.Set<GitHubEmployeeIdentity>()
            .Where(x => x.CompanyId == company && x.EmployeeId == actor).ExecuteDeleteAsync(ct);
    }

    public async Task<IReadOnlyList<GitHubRepositoryOption>> RepositoriesAsync(CancellationToken ct)
    {
        var company = tenant.CompanyId;
        await EnsureActorAsync(company, employee.EmployeeId, OAuthStatePurpose.Company, ct);
        var connection = await GetConnectionAsync(company, ct);
        var providerToken = await github.GetInstallationTokenAsync(connection.InstallationId, null, ct);
        var repositories = await github.ListRepositoriesAsync("/installation/repositories", providerToken, ct);
        var verifiedIds = GetVerifiedIds(connection);

        return repositories.Where(x => x.Owner.Id == connection.GitHubAccountId &&
                (verifiedIds is null || verifiedIds.Contains(x.Id)))
            .Select(x => new GitHubRepositoryOption(x.Id, x.Owner.Login, x.Name, x.FullName, x.DefaultBranch, x.IsPrivate))
            .OrderBy(x => x.FullName, StringComparer.OrdinalIgnoreCase).ToArray();
    }

    public async Task<GitHubProjectStatus> ProjectStatusAsync(string projectId, CancellationToken ct)
    {
        var company = tenant.CompanyId;
        if (await access.ReadProjectAsync(company, employee.EmployeeId, projectId, ct) is null)
            throw new GitHubIntegrationException("Project was not found.", 404);

        var binding = await db.Set<GitHubRepositoryBinding>().AsNoTracking()
            .SingleOrDefaultAsync(x => x.CompanyId == company && x.ProjectId == projectId && x.IsActive, ct);
        if (binding is null)
            return new GitHubProjectStatus(projectId, null, null, null, null, "not-mapped", null);
        var activeConnection = await db.Set<GitHubConnection>().AnyAsync(x =>
            x.CompanyId == company && x.InstallationId == binding.InstallationId && x.IsActive && !x.IsSuspended, ct);
        if (!activeConnection)
            return new GitHubProjectStatus(projectId, null, null, null, null, "unavailable", null);

        var status = await db.Set<GitHubRepositorySync>().AsNoTracking()
            .SingleOrDefaultAsync(x => x.BindingId == binding.Id, ct);
        var state = status is null ? "pending"
            : status.LastFailure is not null ? "retrying"
            : status.CompletedVersion < status.RequestedVersion ? "pending"
            : status.LastSuccessAtUtc is not null ? "synced"
            : "pending";
        return new GitHubProjectStatus(projectId, binding.Id, binding.RepositoryId, binding.FullName,
            binding.DefaultBranch, state, status?.LastSuccessAtUtc);
    }

    public async Task<GitHubProjectStatus> MapRepositoryAsync(string projectId, long repositoryId, CancellationToken ct)
    {
        if (repositoryId <= 0)
            throw new GitHubIntegrationException("A valid repository ID is required.", 400);
        var company = tenant.CompanyId;
        var actor = employee.EmployeeId;
        await EnsureActorAsync(company, actor, OAuthStatePurpose.Company, ct);
        if (await access.ReadProjectAsync(company, actor, projectId, ct) is null)
            throw new GitHubIntegrationException("Project was not found.", 404);

        var connection = await GetConnectionAsync(company, ct);
        EnsureRepositoryGrant(connection, repositoryId);
        var token = await github.GetInstallationTokenAsync(connection.InstallationId, repositoryId, ct);
        var repositories = await github.ListRepositoriesAsync("/installation/repositories", token, ct);
        var providerRepo = repositories.SingleOrDefault(x =>
            x.Id == repositoryId && x.Owner.Id == connection.GitHubAccountId)
            ?? throw new GitHubIntegrationException("This repository is outside the linked GitHub account.", 403);

        await using (var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct))
        {
            await EnsureActorAsync(company, actor, OAuthStatePurpose.Company, ct);
            var current = await GetConnectionAsync(company, ct);
            if (current.InstallationId != connection.InstallationId)
                throw new GitHubIntegrationException("The GitHub connection changed. Select the repository again.", 409);
            EnsureRepositoryGrant(current, repositoryId);

            var bindings = db.Set<GitHubRepositoryBinding>();
            var binding = await bindings.SingleOrDefaultAsync(x => x.CompanyId == company &&
                x.ProjectId == projectId && x.IsActive, ct);
            if (binding is not null && binding.RepositoryId != repositoryId)
                throw new GitHubIntegrationException("Unlink the existing project repository before choosing another.", 409);

            if (binding is null)
            {
                if (await bindings.AnyAsync(x => x.CompanyId == company && x.RepositoryId == repositoryId && x.IsActive, ct))
                    throw new GitHubIntegrationException("This repository is already mapped to another project.", 409);

                binding = new GitHubRepositoryBinding
                {
                    CompanyId = company, ProjectId = projectId, InstallationId = current.InstallationId, RepositoryId = repositoryId,
                    Owner = providerRepo.Owner.Login, Name = providerRepo.Name, FullName = providerRepo.FullName,
                    DefaultBranch = providerRepo.DefaultBranch
                };
                bindings.Add(binding);
                db.Set<GitHubRepositorySync>().Add(new GitHubRepositorySync { BindingId = binding.Id });
                await SaveChangesAsync(ct);
            }

            await transaction.CommitAsync(ct);
        }

        return await ProjectStatusAsync(projectId, ct);
    }

    public async Task UnmapRepositoryAsync(string projectId, CancellationToken ct)
    {
        var company = tenant.CompanyId;
        await EnsureActorAsync(company, employee.EmployeeId, OAuthStatePurpose.Company, ct);
        if (await access.ReadProjectAsync(company, employee.EmployeeId, projectId, ct) is null)
            throw new GitHubIntegrationException("Project was not found.", 404);

        var now = DateTime.UtcNow;
        await db.Set<GitHubRepositoryBinding>()
            .Where(x => x.CompanyId == company && x.ProjectId == projectId && x.IsActive)
            .ExecuteUpdateAsync(set => set.SetProperty(x => x.IsActive, false).SetProperty(x => x.UpdatedAt, now), ct);
    }

    public async Task RequestProjectSyncAsync(string projectId, CancellationToken ct)
    {
        var company = tenant.CompanyId;
        await EnsureActorAsync(company, employee.EmployeeId, OAuthStatePurpose.Company, ct);
        var binding = await db.Set<GitHubRepositoryBinding>().AsNoTracking()
            .SingleOrDefaultAsync(x => x.CompanyId == company && x.ProjectId == projectId && x.IsActive, ct)
            ?? throw new GitHubIntegrationException("No active GitHub repository is mapped to this project.", 404);
        var connection = await GetConnectionAsync(company, ct);
        if (connection.InstallationId != binding.InstallationId)
            throw new GitHubIntegrationException("The project mapping is no longer active.", 409);
        EnsureRepositoryGrant(connection, binding.RepositoryId);
        await sync.RequestSyncAsync(company, binding.InstallationId, binding.RepositoryId, "syntrace_mapping", "resync", ct);
    }

    private async Task<IReadOnlyList<VerifiedInstallation>> EligibleInstallationsAsync(
        long appId, string userToken, long gitHubUserId, CancellationToken ct)
    {
        var installations = await github.ListUserInstallationsAsync(userToken, ct);
        var verified = new List<VerifiedInstallation>();
        foreach (var installation in installations.Where(i => i.AppId == appId && i.SuspendedAt is null).DistinctBy(i => i.Id))
        {
            var account = installation.Account;
            if (account.Type == "User" && account.Id == gitHubUserId)
            {
                verified.Add(new VerifiedInstallation(installation.Id, account.Id, account.Login, account.Type, null));
            }
            else if (account.Type == "Organization")
            {
                // Limit installation-based background reads to repositories the consenting actor administered.
                var repositories = await github.ListRepositoriesAsync($"/user/installations/{installation.Id}/repositories", userToken, ct);
                var allowedIds = repositories
                    .Where(r => r.Owner.Id == account.Id && r.Permissions is { Admin: true })
                    .Select(r => r.Id).Distinct().ToArray();
                if (allowedIds.Length > 0)
                    verified.Add(new VerifiedInstallation(installation.Id, account.Id, account.Login, account.Type, allowedIds));
            }
        }
        return verified;
    }

    private async Task ApplyCompanyConnectionAsync(GitHubOAuthCompletion pending, VerifiedInstallation choice, DateTime now, CancellationToken ct)
    {
        var ownership = await db.Set<GitHubInstallationOwnership>()
            .SingleOrDefaultAsync(x => x.InstallationId == choice.Id, ct);
        if (ownership is not null && ownership.CompanyId != pending.CompanyId)
            throw new GitHubIntegrationException("This GitHub installation is already registered to another company.", 409);

        var connection = await db.Set<GitHubConnection>().SingleOrDefaultAsync(x => x.CompanyId == pending.CompanyId, ct);
        if (connection is { IsActive: true } && connection.InstallationId != choice.Id)
            throw new GitHubIntegrationException("Disconnect the current GitHub installation before linking another one.", 409);

        if (ownership is null)
            db.Set<GitHubInstallationOwnership>().Add(new GitHubInstallationOwnership { InstallationId = choice.Id, CompanyId = pending.CompanyId });
        if (connection is null)
        {
            connection = new GitHubConnection { CompanyId = pending.CompanyId, CreatedAt = now };
            db.Set<GitHubConnection>().Add(connection);
        }

        connection.InstallationId = choice.Id;
        connection.GitHubAccountId = choice.AccountId;
        connection.GitHubAccountLogin = choice.AccountLogin;
        connection.ConnectedByEmployeeId = pending.EmployeeId;
        connection.IsActive = true;
        connection.IsSuspended = false;
        connection.UpdatedAt = now;
        connection.VerifiedRepositoryIdsJson = choice.VerifiedRepositoryIds is null
            ? null : JsonSerializer.Serialize(choice.VerifiedRepositoryIds);

        if (choice.VerifiedRepositoryIds is { } repositoryIds)
        {
            await db.Set<GitHubRepositoryBinding>()
                .Where(x => x.CompanyId == pending.CompanyId && x.InstallationId == choice.Id &&
                    x.IsActive && !repositoryIds.Contains(x.RepositoryId))
                .ExecuteUpdateAsync(set => set.SetProperty(x => x.IsActive, false).SetProperty(x => x.UpdatedAt, now), ct);
        }
    }

    private async Task ApplyEmployeeConnectionAsync(GitHubOAuthCompletion pending, DateTime now, CancellationToken ct)
    {
        var identities = db.Set<GitHubEmployeeIdentity>();
        if (await identities.AnyAsync(x => x.CompanyId == pending.CompanyId && x.GitHubUserId == pending.GitHubUserId &&
                x.EmployeeId != pending.EmployeeId, ct))
            throw new GitHubIntegrationException("That GitHub identity is already linked to an employee in this company.", 409);

        var identity = await identities.SingleOrDefaultAsync(
            x => x.CompanyId == pending.CompanyId && x.EmployeeId == pending.EmployeeId, ct);
        if (identity is null)
        {
            identity = new GitHubEmployeeIdentity { CompanyId = pending.CompanyId, EmployeeId = pending.EmployeeId, CreatedAt = now };
            identities.Add(identity);
        }
        identity.GitHubUserId = pending.GitHubUserId;
        identity.GitHubLogin = pending.GitHubLogin;
        identity.UpdatedAt = now;
    }

    private async Task<GitHubOAuthCompletion> ReadPendingAsync(string proof, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(proof) || proof.Length != 43)
            throw new GitHubIntegrationException("A valid GitHub confirmation ID is required.", 400);
        var hash = Hash(proof);
        var now = DateTime.UtcNow;
        var company = tenant.CompanyId;
        var actor = employee.EmployeeId;
        var pending = await db.Set<GitHubOAuthCompletion>().AsNoTracking().SingleOrDefaultAsync(
            x => x.ProofHash == hash && x.CompanyId == company && x.EmployeeId == actor && x.ExpiresAt > now, ct);
        if (pending is null)
            throw new GitHubIntegrationException("The GitHub confirmation is not available. Start the connection again.", 410);
        await EnsureActorAsync(company, actor, pending.Purpose, ct);
        return pending;
    }

    private async Task EnsureActorAsync(string company, string actor, OAuthStatePurpose purpose, CancellationToken ct)
    {
        var allowed = purpose == OAuthStatePurpose.Company
            ? await access.IsCompanyAdminAsync(company, actor, ct)
            : await db.Employees.AnyAsync(x => x.Id == actor && x.CompanyId == company, ct);
        if (!allowed)
            throw new GitHubIntegrationException("You do not have permission to make this GitHub connection.", 403);
    }

    private async Task<GitHubConnection> GetConnectionAsync(string company, CancellationToken ct) =>
        await db.Set<GitHubConnection>().AsNoTracking().SingleOrDefaultAsync(
            x => x.CompanyId == company && x.IsActive && !x.IsSuspended, ct)
        ?? throw new GitHubIntegrationException("Connect an active GitHub installation first.", 409);

    private static void EnsureRepositoryGrant(GitHubConnection connection, long repositoryId)
    {
        if (GetVerifiedIds(connection) is { } ids && !ids.Contains(repositoryId))
            throw new GitHubIntegrationException("The repository was not included in the administrator's verified grant.", 403);
    }

    private static HashSet<long>? GetVerifiedIds(GitHubConnection connection) =>
        connection.VerifiedRepositoryIdsJson is { } json
            ? JsonSerializer.Deserialize<HashSet<long>>(json) ?? []
            : null;

    private static VerifiedInstallation[] ReadOptions(GitHubOAuthCompletion pending) =>
        JsonSerializer.Deserialize<VerifiedInstallation[]>(pending.EligibleInstallationsJson) ?? [];

    private GitHubOAuthOptions ValidOAuthOptions()
    {
        var config = options.Value;
        if (config.AppId <= 0 || string.IsNullOrWhiteSpace(config.AppSlug) ||
            string.IsNullOrWhiteSpace(config.ClientId) || string.IsNullOrWhiteSpace(config.ClientSecret) ||
            !Uri.TryCreate(config.RedirectUri, UriKind.Absolute, out var redirect) || redirect.Scheme != Uri.UriSchemeHttps)
            throw new GitHubIntegrationException("GitHub App authorization is not configured.", 503);
        return config;
    }

    private async Task SaveChangesAsync(CancellationToken ct)
    {
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException error) when (error.InnerException is SqlException { Number: 2601 or 2627 })
        {
            throw new GitHubIntegrationException("The GitHub connection or repository mapping already changed. Refresh and try again.", 409);
        }
    }

    private static string Hash(string proof) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(proof)));

    private sealed record VerifiedInstallation(long Id, long AccountId, string AccountLogin, string AccountType,
        IReadOnlyList<long>? VerifiedRepositoryIds);
}
