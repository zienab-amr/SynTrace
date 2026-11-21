using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class ProjectIntegrationAccess(SynTraceDbContext db)
{
    public Task<bool> IsCompanyAdminAsync(string companyId, string employeeId, CancellationToken ct) =>
        (from employee in db.Employees
         join employeeRole in db.UserRoles on employee.Id equals employeeRole.UserId
         join role in db.Roles on employeeRole.RoleId equals role.Id
         where employee.Id == employeeId && employee.CompanyId == companyId
            && role.CompanyId == companyId && role.NormalizedName == "ADMIN"
         select role.Id).AnyAsync(ct);

    public async Task<Project?> ReadProjectAsync(
        string companyId, string employeeId, string projectId, CancellationToken ct)
    {
        var isAdmin = await IsCompanyAdminAsync(companyId, employeeId, ct);
        return await db.Projects.IgnoreQueryFilters().AsNoTracking()
            .Where(project => project.CompanyId == companyId && project.ProjectId == projectId)
            .Where(project => isAdmin || project.EmployeeProjects.Any(
                member => member.CompanyId == companyId && member.EmployeeId == employeeId))
            .SingleOrDefaultAsync(ct);
    }
}

public sealed class CurrentCompanyAdminRequirement : IAuthorizationRequirement { }

public sealed class CurrentCompanyAdminHandler(ProjectIntegrationAccess access)
    : AuthorizationHandler<CurrentCompanyAdminRequirement>
{
    public const string Policy = "CurrentCompanyAdmin";

    protected override async Task HandleRequirementAsync(
        AuthorizationHandlerContext context, CurrentCompanyAdminRequirement requirement)
    {
        var companyId = context.User.FindFirstValue("CompanyId");
        var employeeId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (context.User.Identity?.IsAuthenticated == true &&
            !string.IsNullOrEmpty(companyId) && !string.IsNullOrEmpty(employeeId))
        {
            var ct = (context.Resource as Microsoft.AspNetCore.Http.HttpContext)?.RequestAborted
                ?? CancellationToken.None;
            if (await access.IsCompanyAdminAsync(companyId, employeeId, ct))
                context.Succeed(requirement);
        }
    }
}
