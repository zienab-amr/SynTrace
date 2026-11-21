using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Integrations.GitHub;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Repositories;

internal static class GitHubOAuthChecks
{
    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var actor = new Actor();
        await using var db = new SynTraceDbContext(
            new DbContextOptionsBuilder<SynTraceDbContext>().UseSqlite(connection).Options, actor);
        await db.Database.EnsureCreatedAsync();
        db.Companies.Add(new Company { CompanyId = actor.CompanyId, CompanyName = "Test company" });
        db.Employees.AddRange(
            new Employee { Id = "admin", CompanyId = actor.CompanyId, FirstName = "First", LastName = "Admin" },
            new Employee { Id = "employee", CompanyId = actor.CompanyId, FirstName = "First", LastName = "Employee" });
        db.Roles.Add(new Role { Id = "admin-role", CompanyId = actor.CompanyId, Name = "Admin", NormalizedName = "ADMIN" });
        db.UserRoles.Add(new IdentityUserRole<string> { UserId = "admin", RoleId = "admin-role" });
        db.Clients.Add(new Client { ClientId = "test-client", CompanyId = actor.CompanyId, ClientName = "Test client" });
        db.Projects.Add(new Project
        {
            ProjectId = "test-project", CompanyId = actor.CompanyId, ClientId = "test-client", ProjectName = "Test project"
        });
        await db.SaveChangesAsync();

        var keyFolder = Directory.CreateTempSubdirectory("syntrace-github-check-");
        try
        {
            var keyPath = Path.Combine(keyFolder.FullName, "check.pem");
            using (var rsa = RSA.Create(2048))
                await File.WriteAllTextAsync(keyPath, rsa.ExportRSAPrivateKeyPem());
            var config = Options.Create(new GitHubOAuthOptions
            {
                AppId = 100, AppSlug = "syntrace-test", ClientId = "fixture-client-id", ClientSecret = "fixture-secret",
                PrivateKeyPath = keyPath, RedirectUri = "https://syntrace.example/api/integrations/github/callback"
            });
            using var transport = new FakeGitHub();
            using var client = new HttpClient(transport);
            using var cache = new MemoryCache(new MemoryCacheOptions());
            var service = new GitHubOAuthService(db, new OAuthStateRepository(db, new EphemeralDataProtectionProvider()),
                actor, actor, new ProjectIntegrationAccess(db), new GitHubApiClient(new ClientFactory(client), config, cache),
                new SyncTrigger(), config);

            var start = await service.StartAsync(GitHubConnectMode.InstallCompany, default);
            Expect(new Uri(start.Url).AbsolutePath == "/apps/syntrace-test/installations/new", "Admin installation URL");
            var callback = await service.CallbackAsync(State(start.Url), "admin-code", null, default);
            var proof = callback.CompletionId ?? throw new InvalidOperationException("Missing confirmation ID");
            Expect(callback.Status == "confirm" && !await db.Set<GitHubConnection>().AnyAsync(), "The callback waits for authenticated confirmation");
            var choice = await service.PendingAsync(proof, default);
            Expect(choice.Installations is [{ InstallationId: 123, RepositoryCount: 1 }], "Organization grants include admin-managed repositories");
            await service.CompleteAsync(proof, 123, default);
            var repositories = await service.RepositoriesAsync(default);
            Expect(repositories is [{ RepositoryId: 456 }], "Company listing honors the confirmed repository grant");
            var project = await service.MapRepositoryAsync("test-project", 456, default);
            Expect(project is { RepositoryId: 456, SyncStatus: "pending" } && transport.TokenWasRepositoryScoped,
                "Mapping uses a repository-scoped installation token and creates a pending sync");
            Expect(await db.Set<GitHubRepositorySync>().AnyAsync(x => x.BindingId == project.BindingId),
                "Initial sync survives the mapping request");

            actor.EmployeeId = "employee";
            start = await service.StartAsync(GitHubConnectMode.EmployeeIdentity, default);
            var parameters = QueryHelpers.ParseQuery(new Uri(start.Url).Query);
            Expect(parameters.ContainsKey("code_challenge") && !parameters.ContainsKey("scope"), "Employee OAuth uses PKCE and App permissions");
            callback = await service.CallbackAsync(State(start.Url), "employee-code", null, default);
            await service.CompleteAsync(callback.CompletionId!, null, default);
            var identity = await service.EmployeeStatusAsync(default);
            Expect(transport.EmployeeCodeVerifierFound && identity is { Connected: true, GitHubUserId: 700, GitHubLogin: "employee-test" },
                "Employee identity comes from GitHub and the saved PKCE verifier is sent at exchange");
        }
        finally
        {
            keyFolder.Delete(recursive: true);
        }
    }

    private static string State(string url) => QueryHelpers.ParseQuery(new Uri(url).Query)["state"].ToString();

    private static void Expect(bool value, string message)
    {
        if (!value)
            throw new InvalidOperationException(message);
    }

    private sealed class Actor : ICurrentTenant, ICurrentEmployee
    {
        public string CompanyId => "test-company";
        public string EmployeeId { get; set; } = "admin";
    }

    private sealed class ClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class SyncTrigger : IGitHubSyncTrigger
    {
        public Task RequestSyncAsync(string companyId, long installationId, long? repositoryId,
            string eventName, string? action, CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class FakeGitHub : HttpMessageHandler
    {
        public bool TokenWasRepositoryScoped { get; private set; }
        public bool EmployeeCodeVerifierFound { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var path = request.RequestUri!.AbsolutePath;
            var token = request.Headers.Authorization?.Parameter;
            var organization = new { id = 600, login = "org-test", type = "Organization" };
            var installation = new { id = 123, app_id = 100, account = organization, suspended_at = (string?)null };
            var repos = new[]
            {
                new { id = 456, name = "managed", full_name = "org-test/managed", owner = organization,
                    default_branch = "main", @private = true, permissions = new { admin = true } },
                new { id = 457, name = "readable", full_name = "org-test/readable", owner = organization,
                    default_branch = "main", @private = true, permissions = new { admin = false } }
            };
            switch (path)
            {
                case "/login/oauth/access_token":
                    var form = await request.Content!.ReadAsStringAsync(ct);
                    if (!form.Contains("code=employee-code", StringComparison.Ordinal))
                        return Json(new { access_token = "admin-fixture" });
                    EmployeeCodeVerifierFound = form.Contains("code_verifier=", StringComparison.Ordinal);
                    return Json(new { access_token = "employee-fixture" });
                case "/user":
                    return token == "employee-fixture"
                        ? Json(new { id = 700, login = "employee-test", type = "User" })
                        : Json(new { id = 701, login = "admin-test", type = "User" });
                case "/user/installations":
                    return Json(new { total_count = 1, installations = new[] { installation } });
                case "/app/installations/123":
                    return Json(installation);
                case "/app/installations/123/access_tokens":
                    using (var grant = JsonDocument.Parse(await request.Content!.ReadAsStringAsync(ct)))
                    {
                        var scoped = grant.RootElement.TryGetProperty("repository_ids", out var ids);
                        if (scoped)
                            TokenWasRepositoryScoped = ids.GetArrayLength() == 1 && ids[0].GetInt64() == 456;
                        return Json(new { token = scoped ? "scoped-fixture" : "unscoped-fixture", expires_at = DateTimeOffset.UtcNow.AddHours(1) });
                    }
                case "/user/installations/123/repositories":
                case "/installation/repositories":
                    var available = token == "scoped-fixture" ? repos[..1] : repos;
                    return Json(new { total_count = available.Length, repositories = available });
                default:
                    return new HttpResponseMessage(HttpStatusCode.NotFound);
            }
        }

        private static HttpResponseMessage Json(object body) => new(HttpStatusCode.OK)
        {
            Content = JsonContent.Create(body)
        };
    }
}
