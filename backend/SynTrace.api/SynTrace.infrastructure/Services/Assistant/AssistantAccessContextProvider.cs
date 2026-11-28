using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Services.Assistant;

/// <summary>Infrastructure adapter for the assistant access policy and Jira account lookup.</summary>
public sealed class AssistantAccessContextProvider(
    AssistantProjectAccess projectAccess,
    SynTraceDbContext db,
    IOptions<AiServiceOptions> options) : IAssistantAccessContextProvider
{
    public async Task<AssistantAccessContext> GetForCurrentEmployeeAsync(
        string companyId, string employeeId, CancellationToken ct)
    {
        var scope = await projectAccess.GetScopeAsync(companyId, employeeId, ct);
        var canAsk = scope.JiraKeys.Count > 0 ||
            (options.Value.EnableSynTraceProjectScope && scope.SynTraceProjectIds.Count > 0);
        if (!canAsk) return new AssistantAccessContext(scope, null, false);

        var employee = await db.Employees.AsNoTracking()
            .Where(e => e.Id == employeeId && e.CompanyId == companyId)
            .Select(e => new { e.FirstName, e.LastName })
            .SingleOrDefaultAsync(ct);
        if (employee is not null)
        {
            var name = string.Join(" ", new[] { employee.FirstName, employee.LastName }
                .Where(part => !string.IsNullOrWhiteSpace(part))).Trim();
            scope = scope with { EmployeeDisplayName = name.Length <= 300 ? name : name[..300] };
        }

        var jiraAccountId = await db.JiraConnections.AsNoTracking()
            .Where(c => c.CompanyId == companyId && c.ConnectedByEmployeeId == employeeId &&
                        c.JiraConnectionType == JiraConnectionType.Employee && c.status)
            .Select(c => c.JiraAccountId).FirstOrDefaultAsync(ct);

        return new AssistantAccessContext(scope, jiraAccountId, true);
    }
}
