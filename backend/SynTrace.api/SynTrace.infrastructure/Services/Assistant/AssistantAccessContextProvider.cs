using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Services.Assistant;

/// <summary>Infrastructure adapter for the assistant access policy and Jira account lookup.</summary>
public sealed class AssistantAccessContextProvider(
    AssistantProjectAccess projectAccess,
    SynTraceDbContext db,
    IOptions<AiServiceOptions> options,
    IMeetingPermissionService meetingPermissions) : IAssistantAccessContextProvider
{
    public async Task<AssistantAccessContext> GetForCurrentEmployeeAsync(
        string companyId, string employeeId, CancellationToken ct)
    {
        var scope = await projectAccess.GetScopeAsync(companyId, employeeId, ct);
        var canAsk = scope.JiraKeys.Count > 0 ||
            ((options.Value.EnableSynTraceProjectScope || options.Value.EnableMeetingContract) && scope.SynTraceProjectIds.Count > 0);
        if (!canAsk) return new AssistantAccessContext(scope, null, false);

        var jiraAccountId = await db.JiraConnections.AsNoTracking()
            .Where(c => c.CompanyId == companyId && c.ConnectedByEmployeeId == employeeId &&
                        c.JiraConnectionType == JiraConnectionType.Employee && c.status)
            .Select(c => c.JiraAccountId).FirstOrDefaultAsync(ct);

        if (!options.Value.EnableMeetingContract)
            return new AssistantAccessContext(scope, jiraAccountId, true);

        var grants = await meetingPermissions.GetForEmployeeAsync(companyId, employeeId, ct);
        scope = scope with { MeetingPermissions = MeetingAssistantPermissions.From(grants) };
        return new AssistantAccessContext(scope, jiraAccountId, true)
        {
            HistoryCount = Math.Clamp(options.Value.MeetingHistoryCount, 1, 30)
        };
    }
}
