using System.Net;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

internal static class GitHubSyncChecks
{
    private const string CompanyId = "sync-company";
    private const string ProjectId = "sync-project";
    private const string EmployeeId = "sync-employee";
    private const long InstallationId = 301;
    private const long RepositoryId = 303;
    private const string Head = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    private const string Tree = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    private const string Blob = "cccccccccccccccccccccccccccccccccccccccc";

    public static async Task RunAsync()
    {
        var keyPath = Path.GetTempFileName();
        try
        {
            using var rsa = RSA.Create(2048);
            await File.WriteAllTextAsync(keyPath, rsa.ExportRSAPrivateKeyPem());
            await using var connection = new SqliteConnection("Data Source=:memory:");
            await connection.OpenAsync();
            await RunAsync(connection, keyPath);
        }
        finally { File.Delete(keyPath); }
    }

    private static async Task RunAsync(SqliteConnection connection, string keyPath)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["GithubOAuth:ClientId"] = "fixture",
            ["GithubOAuth:PrivateKeyPath"] = keyPath,
            ["GitHubSync:Enabled"] = "true"
        }).Build();
        var fake = new GitHubFixture();
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddDbContext<SynTraceDbContext>(o => o.UseSqlite(connection));
        services.AddGitHubOAuth(configuration);
        services.AddSingleton<IHttpClientFactory>(fake);
        services.AddGitHubSync(configuration, runWorker: true);
        await using var provider = services.BuildServiceProvider();
        string id;
        await using (var scope = provider.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
            await db.Database.EnsureCreatedAsync();
            db.Companies.Add(new Company { CompanyId = CompanyId, CompanyName = "Sync fixture" });
            db.Employees.Add(new Employee { Id = EmployeeId, CompanyId = CompanyId, FirstName = "GitHub", LastName = "Fixture" });
            db.Clients.Add(new Client { ClientId = "sync-client", CompanyId = CompanyId, ClientName = "Fixture" });
            db.Projects.Add(new Project { ProjectId = ProjectId, CompanyId = CompanyId, ClientId = "sync-client", ProjectName = "Fixture" });
            db.Set<GitHubInstallationOwnership>().Add(new GitHubInstallationOwnership { InstallationId = InstallationId, CompanyId = CompanyId });
            db.Set<GitHubConnection>().Add(new GitHubConnection
            {
                CompanyId = CompanyId, InstallationId = InstallationId, GitHubAccountId = 302,
                GitHubAccountLogin = "owner", ConnectedByEmployeeId = EmployeeId
            });
            var binding = new GitHubRepositoryBinding
            {
                CompanyId = CompanyId, ProjectId = ProjectId, InstallationId = InstallationId,
                RepositoryId = RepositoryId, Owner = "owner", Name = "repo", FullName = "owner/repo"
            };
            id = binding.Id;
            db.Add(binding);
            db.Add(new GitHubRepositorySync { BindingId = id });
            await db.SaveChangesAsync();
        }

        // A separate scope per drain iteration mirrors each run of the actual worker.
        await RunPhasesAsync(provider, 5);
        await using (var scope = provider.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
            var items = db.Set<GitHubSyncedItem>().AsNoTracking().Where(x => x.BindingId == id);
            Expect(await items.CountAsync(x => x.Kind == "commit") == 11, "Both pages of historical commits were persisted.");
            Expect(await items.CountAsync(x => x.Kind == "pull_request") == 1, "Historical pull request was persisted.");
            var file = await items.SingleAsync(x => x.Kind == "file");
            Expect(!file.PayloadJson.Contains("example-test-secret") && file.PayloadJson.Contains("[REDACTED]"), "Published code is redacted.");
            var state = await db.Set<GitHubRepositorySync>().AsNoTracking().SingleAsync(x => x.BindingId == id);
            Expect(state.LastIndexedHeadSha == Head && state.CompletedVersion == state.RequestedVersion,
                "Code and history complete the same pinned revision.");
            Expect(state.DueAtUtc - state.LastSuccessAtUtc >= TimeSpan.FromHours(5.99),
                "Recheck is scheduled six hours after success.");
            await scope.ServiceProvider.GetRequiredService<IGitHubSyncTrigger>()
                .RequestSyncAsync(CompanyId, InstallationId, RepositoryId, "push", null, CancellationToken.None);
        }

        await RunPhasesAsync(provider, 3);
        Expect(fake.BlobRequests == 1, "An unchanged code revision is not fetched or indexed twice.");
        fake.RepositoryGranted = false;
        await using (var scope = provider.CreateAsyncScope())
            await scope.ServiceProvider.GetRequiredService<IGitHubSyncTrigger>()
                .RequestSyncAsync(CompanyId, InstallationId, null, "installation_repositories", "removed", CancellationToken.None);

        await RunPhasesAsync(provider, 1);
        await using (var scope = provider.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
            Expect(!await db.Set<GitHubSyncedItem>().AnyAsync(x => x.BindingId == id), "Revocation purges local source data.");
            var eventRow = await db.Set<GitHubDataOutbox>().SingleAsync(x => x.BindingId == id);
            Expect(eventRow.EventType == "github.repository.revoked", "Revocation clears stale unpublished events and queues cleanup.");
        }
    }

    private static async Task RunPhasesAsync(ServiceProvider provider, int count)
    {
        var step = typeof(GitHubSyncRegistration).Assembly.GetType("SynTrace.Infrastructure.Integrations.GitHub.GitHubSyncWorkStep", true)!;
        var execute = step.GetMethod("RunAsync", BindingFlags.Public | BindingFlags.Instance)!;
        for (var i = 0; i < count; i++)
        {
            await using var scope = provider.CreateAsyncScope();
            var completion = (Task<bool>)execute.Invoke(scope.ServiceProvider.GetRequiredService(step), [CancellationToken.None])!;
            Expect(await completion, "A durable sync stage was claimed.");
        }
    }

    private static void Expect(bool condition, string failure)
    {
        if (!condition)
            throw new InvalidOperationException(failure);
    }

    private sealed class GitHubFixture : HttpMessageHandler, IHttpClientFactory
    {
        public bool RepositoryGranted { get; set; } = true;
        public int BlobRequests { get; private set; }
        private static readonly string Source = "var client_secret = \"example-test-secret\";\n";
        private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
        public HttpClient CreateClient(string name) => new(this, disposeHandler: false);

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var url = request.RequestUri!;
            var path = url.AbsolutePath;
            object response;
            if (path == $"/app/installations/{InstallationId}/access_tokens")
                response = new { token = "fixture-token", expires_at = DateTimeOffset.UtcNow.AddHours(1) };
            else if (path == $"/app/installations/{InstallationId}")
                response = new { id = InstallationId, app_id = 300, account = new { id = 302, login = "owner", type = "Organization" } };
            else if (path == "/installation/repositories")
                response = new { repositories = RepositoryGranted ? new[]
                {
                    new { id = RepositoryId, owner = new { login = "owner" }, name = "repo", default_branch = "main", @private = true }
                } : [] };
            else if (path == "/repos/owner/repo/branches/main")
                response = new { commit = new { sha = Head } };
            else if (path == "/repos/owner/repo/commits")
                response = (url.Query.EndsWith("page=1") ? Enumerable.Range(1, 10) : Enumerable.Range(11, 1))
                    .Select(i => new { sha = i.ToString("x40"), commit = new { message = "SYNC-1 Change" } }).ToArray();
            else if (path.StartsWith("/repos/owner/repo/commits/"))
                response = new { files = new[] { new { filename = "Program.cs", status = "modified" } } };
            else if (path == "/repos/owner/repo/pulls")
                response = new[] { new { number = 1, updated_at = "2026-11-20T11:00:00Z" } };
            else if (path == "/repos/owner/repo/pulls/1")
                response = new { title = "SYNC-1 Feature", updated_at = "2026-11-20T11:00:00Z", state = "open", changed_files = 0, commits = 0 };
            else if (path is "/repos/owner/repo/pulls/1/files" or "/repos/owner/repo/pulls/1/commits")
                response = Array.Empty<object>();
            else if (path == $"/repos/owner/repo/git/commits/{Head}")
                response = new { tree = new { sha = Tree } };
            else if (path == $"/repos/owner/repo/git/trees/{Tree}")
                response = new { truncated = false, tree = new[] { new { sha = Blob, mode = "100644", type = "blob", path = "Program.cs", size = Encoding.UTF8.GetByteCount(Source) } } };
            else if (path == $"/repos/owner/repo/git/blobs/{Blob}")
            {
                BlobRequests++;
                response = new { encoding = "base64", content = Convert.ToBase64String(Encoding.UTF8.GetBytes(Source)) };
            }
            else
                throw new InvalidOperationException("Unexpected fixture request: " + path);

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(JsonSerializer.Serialize(response, Json), Encoding.UTF8, "application/json")
            });
        }
    }
}
