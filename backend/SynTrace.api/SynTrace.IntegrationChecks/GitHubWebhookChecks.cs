using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using SynTrace.Application.Integrations.GitHub;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

internal static class GitHubWebhookChecks
{
    private const string CompanyId = "webhook-test-company";
    private const string EmployeeId = "webhook-test-employee";
    private const string ClientId = "webhook-test-client";
    private const string ProjectId = "webhook-test-project";
    private const long InstallationId = 101;
    private const long RepositoryId = 202;

    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var dbOptions = new DbContextOptionsBuilder<SynTraceDbContext>().UseSqlite(connection).Options;
        await using var db = new SynTraceDbContext(dbOptions);
        await db.Database.EnsureCreatedAsync();
        var binding = await SeedAsync(db);

        var secret = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["GithubOAuth:WebhookSecret"] = secret
        }).Build();
        var ingress = new GitHubWebhookIngress(db, configuration, NullLogger<GitHubWebhookIngress>.Instance);
        var delivery = Guid.NewGuid();
        var body = FormBody(RepositoryId);
        var signature = Signature(secret, body);

        Expect(await ReceiveAsync(ingress, body, signature, delivery) == GitHubWebhookReceipt.Accepted,
            "A signed notification for a bound repository is accepted.");
        Expect(await ReceiveAsync(ingress, body, signature, delivery) == GitHubWebhookReceipt.Duplicate,
            "The delivery identifier deduplicates later redelivery.");

        var row = await db.Set<GitHubWebhookDelivery>().AsNoTracking().SingleAsync();
        Expect(row.Id == delivery && row.CompanyId == CompanyId && row.InstallationId == InstallationId &&
            row.RepositoryId == RepositoryId && row.BindingId == binding.Id && row.EventName == "push" &&
            row.NextDispatchAtUtc == row.ReceivedAtUtc && row.LastPublishedAtUtc is null,
            "The receipt records the local binding and durable dispatch state before requiring a broker.");

        var otherBody = FormBody(RepositoryId + 1);
        Expect(await ReceiveAsync(ingress, otherBody, Signature(secret, otherBody), Guid.NewGuid()) == GitHubWebhookReceipt.Ignored,
            "A signed notification for a repository outside the project binding creates no pending work.");
        Expect(await ReceiveAsync(ingress, body, null, Guid.NewGuid()) == GitHubWebhookReceipt.Unauthorized,
            "The ingress requires a signature independently of the event data.");
        var incomplete = "{}"u8.ToArray();
        Expect(await ReceiveAsync(ingress, incomplete, Signature(secret, incomplete), Guid.NewGuid()) == GitHubWebhookReceipt.Invalid,
            "Malformed normalized event context creates no pending work.");
        Expect(await db.Set<GitHubWebhookDelivery>().CountAsync() == 1, "Rejected and ignored events are not persisted.");
    }

    private static async Task<GitHubRepositoryBinding> SeedAsync(SynTraceDbContext db)
    {
        db.Companies.Add(new Company { CompanyId = CompanyId, CompanyName = "Webhook Fixtures" });
        db.Employees.Add(new Employee { Id = EmployeeId, CompanyId = CompanyId, FirstName = "Webhook", LastName = "Fixture" });
        db.Clients.Add(new Client { ClientId = ClientId, CompanyId = CompanyId, ClientName = "Fixture Client" });
        db.Projects.Add(new Project { ProjectId = ProjectId, CompanyId = CompanyId, ClientId = ClientId, ProjectName = "Fixture Project" });
        db.Set<GitHubInstallationOwnership>().Add(new GitHubInstallationOwnership { InstallationId = InstallationId, CompanyId = CompanyId });
        db.Set<GitHubConnection>().Add(new GitHubConnection
        {
            InstallationId = InstallationId,
            CompanyId = CompanyId,
            GitHubAccountId = 303,
            GitHubAccountLogin = "fixture-owner",
            ConnectedByEmployeeId = EmployeeId
        });
        var binding = new GitHubRepositoryBinding
        {
            InstallationId = InstallationId,
            CompanyId = CompanyId,
            RepositoryId = RepositoryId,
            ProjectId = ProjectId,
            Owner = "fixture-owner",
            Name = "fixture-repository",
            FullName = "fixture-owner/fixture-repository"
        };
        db.Set<GitHubRepositoryBinding>().Add(binding);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        return binding;
    }

    private static async Task<GitHubWebhookReceipt> ReceiveAsync(
        GitHubWebhookIngress ingress, byte[] payload, string? signature, Guid id)
    {
        using var body = new MemoryStream(payload);
        return await ingress.ReceiveAsync(body, signature, id.ToString("D"), "push", CancellationToken.None);
    }

    private static byte[] FormBody(long repositoryId) => JsonSerializer.SerializeToUtf8Bytes(new
    {
        installation = new { id = InstallationId },
        repository = new { id = repositoryId },
        @ref = "refs/heads/main"
    });

    private static string Signature(string secret, byte[] payload) =>
        "sha256=" + Convert.ToHexStringLower(HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), payload));

    private static void Expect(bool condition, string message)
    {
        if (!condition)
            throw new InvalidOperationException(message);
    }
}
