using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Services.Assistant;

internal static class AssistantScopeChecks
{
    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = new SynTraceDbContext(new DbContextOptionsBuilder<SynTraceDbContext>()
            .UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();

        var company = new Company { CompanyId = "a", CompanyName = "Company A" };
        var employee = new Employee { Id = "employee", CompanyId = company.CompanyId, FirstName = "Test", LastName = "Member" };
        var client = new Client { ClientId = "client-a", CompanyId = company.CompanyId, ClientName = "Client A" };
        db.AddRange(company, employee, client);
        db.AddRange(
            new JiraProject { Id = "jira-p1", CompanyId = company.CompanyId, Key = "TEAM", ExternalId = "10001" },
            new JiraProject { Id = "jira-p2", CompanyId = company.CompanyId, Key = "OTHER", ExternalId = "10002" });
        db.AddRange(
            new Project { ProjectId = "p1", CompanyId = company.CompanyId, ClientId = client.ClientId, ProjectName = "Team", JiraProjectId = "jira-p1" },
            new Project { ProjectId = "p2", CompanyId = company.CompanyId, ClientId = client.ClientId, ProjectName = "Other", JiraProjectId = "jira-p2" });
        db.Add(new EmployeeProject { EmployeeId = employee.Id, CompanyId = company.CompanyId, ProjectId = "p1", Role = "Member" });
        var jira = new JiraConnection
        {
            Id = "jira-install", CompanyId = company.CompanyId, ConnectedByEmployeeId = employee.Id,
            JiraConnectionType = JiraConnectionType.Company
        };
        db.Add(jira);
        await db.SaveChangesAsync();

        var assistant = new AssistantProjectAccess(db, new ProjectIntegrationAccess(db));
        var scope = await assistant.GetScopeAsync(company.CompanyId, employee.Id, default);
        if (!scope.JiraKeys.SequenceEqual(new[] { "TEAM" }) || !scope.SynTraceProjectIds.SequenceEqual(new[] { "p1" }))
            throw new InvalidOperationException("Assistant access must follow project membership.");

        jira.status = false;
        await db.SaveChangesAsync();
        scope = await assistant.GetScopeAsync(company.CompanyId, employee.Id, default);
        if (scope.JiraKeys.Count != 0 || !scope.SynTraceProjectIds.SequenceEqual(new[] { "p1" }))
            throw new InvalidOperationException("Disconnected Jira sources must be unavailable to the assistant.");
    }
}
