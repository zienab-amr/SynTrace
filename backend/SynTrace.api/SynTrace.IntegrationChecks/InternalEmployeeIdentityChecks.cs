using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Repositories;

internal static class InternalEmployeeIdentityChecks
{
    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<SynTraceDbContext>().UseSqlite(connection).Options;
        await using var db = new SynTraceDbContext(options, new TestTenant());
        await db.Database.EnsureCreatedAsync();

        db.Companies.AddRange(
            new Company { CompanyId = "company-a", CompanyName = "A" },
            new Company { CompanyId = "company-b", CompanyName = "B" });
        db.Employees.AddRange(
            Employee("a1", "company-a"), Employee("a2", "company-a"),
            Employee("a3", "company-a"), Employee("b1", "company-b"));
        await db.SaveChangesAsync();

        db.Set<GitHubEmployeeIdentity>().AddRange(
            GitHub("company-a", "a1", 1001, "alice"),
            GitHub("company-a", "a2", 1002, "bob"),
            GitHub("company-b", "b1", 9001, "outsider"));
        db.JiraConnections.AddRange(
            Jira("site-a", "company-a", "a1", JiraConnectionType.Company, "cloud-a", "org", true),
            Jira("jira-a1", "company-a", "a1", JiraConnectionType.Employee, "cloud-a", "jira-1", true),
            Jira("jira-a2", "company-a", "a2", JiraConnectionType.Employee, "cloud-a", "jira-2", false),
            Jira("jira-a3", "company-a", "a3", JiraConnectionType.Employee, "other-cloud", "jira-3", true),
            Jira("site-b", "company-b", "b1", JiraConnectionType.Company, "cloud-b", "org-b", true),
            Jira("jira-b1", "company-b", "b1", JiraConnectionType.Employee, "cloud-b", "jira-b", true));
        await db.SaveChangesAsync();

        var lookup = new EmployeeIdentityLookupRepository(db);
        Check((await lookup.GetCompanyIdentitiesAsync("missing-company", CancellationToken.None)).Count == 0,
            "Unknown company must return no data.");
        var mapped = await lookup.GetCompanyIdentitiesAsync("company-a", CancellationToken.None);
        Check(mapped.Count == 3, "Every employee of the requested tenant must be returned.");
        var alice = mapped.Single(x => x.EmployeeId == "a1");
        Check(alice.GitHubUserId == 1001 && alice.GitHubLogin == "alice" && alice.JiraAccountId == "jira-1",
            "Valid Jira/GitHub linked identity must be mapped.");
        var bob = mapped.Single(x => x.EmployeeId == "a2");
        Check(bob.GitHubUserId == 1002 && bob.JiraAccountId is null,
            "Inactive employee Jira links must not be returned.");
        Check(mapped.Single(x => x.EmployeeId == "a3").JiraAccountId is null,
            "Employee Jira link from another cloud must not be returned.");
        Check(mapped.All(x => x.EmployeeId != "b1" && x.GitHubUserId != 9001),
            "Other company identities must not leak.");

        // Duplicate Jira links can occur because the Jira schema enforces only one
        // link per employee, not unique Jira account ownership within the company.
        db.JiraConnections.Add(Jira("jira-a2-active", "company-a", "a2", JiraConnectionType.Employee,
            "cloud-a", "jira-1", true));
        await db.SaveChangesAsync();
        mapped = await lookup.GetCompanyIdentitiesAsync("company-a", CancellationToken.None);
        Check(mapped.Single(x => x.EmployeeId == "a1").JiraAccountId is null &&
            mapped.Single(x => x.EmployeeId == "a2").JiraAccountId is null,
            "Ambiguous shared Jira identities must not claim a specific employee.");

        var companySite = await db.JiraConnections.SingleAsync(x => x.Id == "site-a");
        companySite.status = false;
        await db.SaveChangesAsync();
        mapped = await lookup.GetCompanyIdentitiesAsync("company-a", CancellationToken.None);
        Check(mapped.All(x => x.JiraAccountId is null),
            "No employee Jira identities should be returned after the company site disconnects.");
    }

    private static Employee Employee(string id, string company) => new()
    {
        Id = id, UserName = id, FirstName = "Test", LastName = "User", CompanyId = company
    };

    private static GitHubEmployeeIdentity GitHub(string company, string employee, long userId, string login) => new()
    {
        CompanyId = company, EmployeeId = employee, GitHubUserId = userId, GitHubLogin = login
    };

    private static JiraConnection Jira(string id, string company, string employee,
        JiraConnectionType type, string cloudId, string accountId, bool active) => new()
    {
        Id = id, CompanyId = company, ConnectedByEmployeeId = employee,
        JiraConnectionType = type, CloudId = cloudId, JiraAccountId = accountId,
        SiteUrl = "https://test.atlassian.net", status = active
    };

    private static void Check(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private sealed class TestTenant : ICurrentTenant
    {
        public string CompanyId => "company-b"; // Proves lookup depends on explicit query company, not JWT tenant filter.
    }
}
