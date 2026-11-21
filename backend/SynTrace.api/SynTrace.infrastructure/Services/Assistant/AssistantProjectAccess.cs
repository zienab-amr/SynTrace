using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Services.Assistant;

public sealed class AssistantProjectAccess(SynTraceDbContext db, ProjectIntegrationAccess access)
{
    public async Task<AssistantProjectScope> GetScopeAsync(
        string companyId, string employeeId, CancellationToken ct)
    {
        if (!await db.Employees.AnyAsync(x => x.CompanyId == companyId && x.Id == employeeId, ct))
            return new([], []);

        var isAdmin = await access.IsCompanyAdminAsync(companyId, employeeId, ct);
        var projects = db.Projects.IgnoreQueryFilters().AsNoTracking().Where(project =>
            project.CompanyId == companyId && (isAdmin || project.EmployeeProjects.Any(member =>
                member.CompanyId == companyId && member.EmployeeId == employeeId)));
        var projectIds = await projects.Select(project => project.ProjectId).OrderBy(id => id).ToListAsync(ct);

        if (!await db.JiraConnections.AnyAsync(x => x.CompanyId == companyId && x.status
                && x.JiraConnectionType == JiraConnectionType.Company, ct))
            return new([], projectIds);

        var jiraKeys = await (from project in projects
            join jira in db.JiraProjects.IgnoreQueryFilters() on project.JiraProjectId equals jira.Id
            where jira.CompanyId == companyId && jira.Key != null
            select jira.Key!).Distinct().OrderBy(key => key).ToListAsync(ct);
        return new(jiraKeys, projectIds);
    }
}
