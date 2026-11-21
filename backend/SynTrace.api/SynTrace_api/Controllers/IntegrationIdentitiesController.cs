using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/integrations/identities")]
public sealed class IntegrationIdentitiesController(
    SynTraceDbContext db, ICurrentTenant tenant, ICurrentEmployee currentEmployee) : ControllerBase
{
    [HttpGet("me")]
    public async Task<IActionResult> GetMyLinks(CancellationToken ct)
    {
        var companyId = tenant.CompanyId;
        var employeeId = currentEmployee.EmployeeId;
        if (!await db.Employees.AnyAsync(x => x.CompanyId == companyId && x.Id == employeeId, ct))
            return Forbid();

        var gitHub = await db.Set<GitHubEmployeeIdentity>().AsNoTracking()
            .Where(x => x.CompanyId == companyId && x.EmployeeId == employeeId)
            .Select(x => new { userId = x.GitHubUserId, login = x.GitHubLogin }).SingleOrDefaultAsync(ct);
        var jiraSite = await db.JiraConnections.AsNoTracking().Where(x => x.CompanyId == companyId
                && x.JiraConnectionType == JiraConnectionType.Company && x.status)
            .Select(x => x.CloudId).SingleOrDefaultAsync(ct);

        var jira = jiraSite is null ? null : await db.JiraConnections.AsNoTracking()
            .Where(x => x.CompanyId == companyId && x.ConnectedByEmployeeId == employeeId && x.CloudId == jiraSite
                && x.JiraConnectionType == JiraConnectionType.Employee && x.status)
            .Select(x => new { accountId = x.JiraAccountId, cloudId = x.CloudId }).SingleOrDefaultAsync(ct);
        var ambiguousJira = jira is not null && (string.IsNullOrEmpty(jira.accountId) ||
            await db.JiraConnections.AnyAsync(x => x.CompanyId == companyId && x.ConnectedByEmployeeId != employeeId &&
                x.CloudId == jiraSite && x.JiraAccountId == jira.accountId && x.status &&
                x.JiraConnectionType == JiraConnectionType.Employee, ct));

        return Ok(new
        {
            employeeId,
            github = gitHub,
            jira = ambiguousJira ? null : jira,
            linkedTogether = gitHub is not null && jira is not null && !ambiguousJira,
            jiraIdentityAmbiguous = ambiguousJira
        });
    }
}
