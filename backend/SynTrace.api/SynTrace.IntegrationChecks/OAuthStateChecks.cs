using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Integrations;
using SynTrace.Domain.Enums;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Repositories;

internal static class OAuthStateChecks
{
    private const string CompanyId = "test-company";
    private const string EmployeeId = "test-employee";

    public static async Task RunAsync()
    {
        var connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = $"OAuthStateChecks-{Guid.NewGuid():N}",
            Mode = SqliteOpenMode.Memory,
            Cache = SqliteCacheMode.Shared
        }.ToString();

        await using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<SynTraceDbContext>().UseSqlite(connectionString).Options;
        var protection = new EphemeralDataProtectionProvider();

        await using var db = new SynTraceDbContext(options);
        await db.Database.EnsureCreatedAsync();
        db.Companies.Add(new Company { CompanyId = CompanyId, CompanyName = "Test Company" });
        db.Employees.Add(new Employee
        {
            Id = EmployeeId,
            CompanyId = CompanyId,
            FirstName = "Test",
            LastName = "Employee",
            UserName = "example-user"
        });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var repository = new OAuthStateRepository(db, protection);
        await CheckProviderPurposeAndVerifierAsync(db, repository);
        await CheckLegacyJiraAndExpirationAsync(db, repository);
        await CheckConcurrentConsumptionAsync(repository, options, protection);
    }

    private static async Task CheckProviderPurposeAndVerifierAsync(SynTraceDbContext db, IOAuthStateRepository repository)
    {
        const string verifier = "isolated-test-verifier-for-pkce-round-trip-2026";
        var state = await repository.CreateAsync(IntegrationProvider.GitHub, OAuthStatePurpose.Employee,
            CompanyId, EmployeeId, verifier);

        var stored = await db.OAuthStates.AsNoTracking().SingleAsync(row => row.StateHash == Hash(state));
        Expect(stored.StateHash != state, "Only a hash of the outgoing state value is stored.");
        Expect(!string.IsNullOrEmpty(stored.EncryptedCodeVerifier) && stored.EncryptedCodeVerifier != verifier,
            "The PKCE verifier is protected in storage.");

        Expect(await repository.TryConsumeAsync(state, IntegrationProvider.Jira) is null,
            "The Jira callback does not consume GitHub state.");
        Expect(await repository.TryConsumeAsync(state, IntegrationProvider.GitHub, OAuthStatePurpose.Company) is null,
            "A company callback does not consume employee state.");

        var result = await repository.TryConsumeAsync(state, IntegrationProvider.GitHub, OAuthStatePurpose.Employee);
        Expect(result is { CompanyId: CompanyId, EmployeeId: EmployeeId, Purpose: OAuthStatePurpose.Employee }
            && result.CodeVerifier == verifier, "The matching callback receives the original actor and PKCE verifier.");
        Expect(await repository.TryConsumeAsync(state, IntegrationProvider.GitHub) is null,
            "A completed state cannot be consumed again.");
    }

    private static async Task CheckLegacyJiraAndExpirationAsync(SynTraceDbContext db, IOAuthStateRepository repository)
    {
        var legacyState = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
        var expiredState = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        db.OAuthStates.AddRange(
            StateRow(legacyState, DateTime.UtcNow.AddMinutes(1)),
            StateRow(expiredState, DateTime.UtcNow.AddMinutes(-1)));
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var result = await repository.TryConsumeAsync(legacyState, IntegrationProvider.Jira);
        Expect(result is { CompanyId: CompanyId, EmployeeId: EmployeeId, Purpose: OAuthStatePurpose.Company, CodeVerifier: null },
            "A migrated Jira state using the old wire format still resolves to its original purpose and actor.");
        Expect(await repository.TryConsumeAsync(expiredState, IntegrationProvider.Jira) is null,
            "Expired state never completes a callback.");
    }

    private static async Task CheckConcurrentConsumptionAsync(
        IOAuthStateRepository repository,
        DbContextOptions<SynTraceDbContext> options,
        IDataProtectionProvider protection)
    {
        var state = await repository.CreateAsync(IntegrationProvider.Jira, OAuthStatePurpose.Company, CompanyId, EmployeeId);

        Task<ConsumedOAuthState?> ConsumeOnSeparateConnectionAsync() => Task.Run(async () =>
        {
            await using var db = new SynTraceDbContext(options);
            return await new OAuthStateRepository(db, protection).TryConsumeAsync(state, IntegrationProvider.Jira);
        });

        var results = await Task.WhenAll(ConsumeOnSeparateConnectionAsync(), ConsumeOnSeparateConnectionAsync());
        Expect(results.Count(result => result is not null) == 1, "Exactly one concurrent callback can consume a state.");
    }

    private static OAuthState StateRow(string state, DateTime expiresAt) => new()
    {
        StateHash = Hash(state),
        CompanyId = CompanyId,
        EmployeeId = EmployeeId,
        Provider = IntegrationProvider.Jira,
        Purpose = OAuthStatePurpose.Company,
        ExpiresAt = expiresAt
    };

    private static string Hash(string state) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(state)));

    private static void Expect(bool condition, string assertion)
    {
        if (!condition)
            throw new InvalidOperationException(assertion);
    }
}
