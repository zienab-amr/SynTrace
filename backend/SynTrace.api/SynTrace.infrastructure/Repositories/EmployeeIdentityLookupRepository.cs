using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts.Repositories;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories;

/// <summary>
/// Maps provider identities to the SynTrace employee who linked them. The company ID
/// is always applied explicitly: the internal AI endpoint does not have a user JWT
/// and must not rely on the current-tenant global query filter.
/// </summary>
public sealed class EmployeeIdentityLookupRepository(SynTraceDbContext db)
    : IEmployeeIdentityLookupRepository
{
    public async Task<IReadOnlyList<InternalEmployeeIdentityDTO>> GetCompanyIdentitiesAsync(
        string companyId,
        CancellationToken cancellationToken)
    {
        var employeeIds = await db.Employees.AsNoTracking()
            .Where(e => e.CompanyId == companyId)
            .OrderBy(e => e.Id)
            .Select(e => e.Id)
            .ToListAsync(cancellationToken);

        if (employeeIds.Count == 0)
            return Array.Empty<InternalEmployeeIdentityDTO>();

        // GitHub personal identity is linked through a separate employee OAuth flow.
        // Never use a GitHub organization/installation account as an employee identity.
        var githubLinks = await db.Set<GitHubEmployeeIdentity>().AsNoTracking()
            .Where(g => g.CompanyId == companyId)
            .Select(g => new { g.EmployeeId, g.GitHubUserId, g.GitHubLogin })
            .ToListAsync(cancellationToken);
        var githubByEmployee = githubLinks.ToDictionary(g => g.EmployeeId, StringComparer.Ordinal);

        // Only an employee's active Jira identity on the company's currently connected
        // Jira site is meaningful for matching an issue assignee to an employee.
        var activeCloudId = await db.JiraConnections.AsNoTracking()
            .Where(c => c.CompanyId == companyId && c.JiraConnectionType == JiraConnectionType.Company && c.status)
            .Select(c => c.CloudId)
            .FirstOrDefaultAsync(cancellationToken);

        List<JiraEmployeeLink> jiraLinks = string.IsNullOrWhiteSpace(activeCloudId)
            ? new List<JiraEmployeeLink>()
            : await db.JiraConnections.AsNoTracking()
                .Where(c => c.CompanyId == companyId && c.JiraConnectionType == JiraConnectionType.Employee &&
                    c.status && c.CloudId == activeCloudId && c.JiraAccountId != "")
                .Select(c => new JiraEmployeeLink(c.ConnectedByEmployeeId, c.JiraAccountId))
                .ToListAsync(cancellationToken);

        // A Jira account can otherwise be linked by multiple employees. Do not
        // assign an ambiguous external identity to either employee: the AI must not
        // claim the wrong person wrote a commit or owns a ticket.
        var ambiguousAccountIds = jiraLinks
            .GroupBy(j => j.AccountId, StringComparer.Ordinal)
            .Where(group => group.Select(j => j.EmployeeId).Distinct(StringComparer.Ordinal).Count() > 1)
            .Select(group => group.Key)
            .ToHashSet(StringComparer.Ordinal);
        var jiraByEmployee = jiraLinks
            .Where(j => !ambiguousAccountIds.Contains(j.AccountId))
            .ToDictionary(j => j.EmployeeId, j => j.AccountId, StringComparer.Ordinal);

        return employeeIds.Select(employeeId =>
        {
            githubByEmployee.TryGetValue(employeeId, out var github);
            jiraByEmployee.TryGetValue(employeeId, out var jiraAccountId);
            return new InternalEmployeeIdentityDTO(
                employeeId, jiraAccountId, github?.GitHubUserId, github?.GitHubLogin);
        }).ToArray();
    }

    private sealed record JiraEmployeeLink(string EmployeeId, string AccountId);
}
