using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Application.Exceptions;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Services.Meetings;

public sealed class MeetingPermissionService(
    SynTraceDbContext db, ICurrentTenant tenant, ICurrentEmployee actor,
    ProjectIntegrationAccess access) : IMeetingPermissionService
{
    // Check current role assignments in SQL, not role names or potentially stale JWT claims.
    public async Task<IReadOnlySet<string>> GetForEmployeeAsync(
        string companyId, string employeeId, CancellationToken ct)
    {
        var values = await (from employee in db.Employees.AsNoTracking()
            join assignment in db.UserRoles.AsNoTracking() on employee.Id equals assignment.UserId
            join role in db.Roles.AsNoTracking() on assignment.RoleId equals role.Id
            join claim in db.RoleClaims.AsNoTracking() on role.Id equals claim.RoleId
            where employee.Id == employeeId && employee.CompanyId == companyId
                && role.CompanyId == companyId && claim.ClaimType == MeetingPermission.ClaimType
            select claim.ClaimValue).ToListAsync(ct);
        return values.OfType<string>().Where(x => MeetingPermission.All.Contains(x, StringComparer.Ordinal))
            .ToHashSet(StringComparer.Ordinal);
    }

    public async Task<IReadOnlyList<string>> GetForRoleAsync(string roleId, CancellationToken ct)
    {
        await RequireRoleAsync(roleId, ct);
        var values = await db.RoleClaims.AsNoTracking()
            .Where(c => c.RoleId == roleId && c.ClaimType == MeetingPermission.ClaimType)
            .Select(c => c.ClaimValue).ToListAsync(ct);
        return values.OfType<string>().Where(x => MeetingPermission.All.Contains(x, StringComparer.Ordinal))
            .Distinct(StringComparer.Ordinal).OrderBy(x => x, StringComparer.Ordinal).ToArray();
    }

    public async Task<IReadOnlyList<string>> ReplaceForRoleAsync(
        string roleId, IReadOnlyList<string> permissions, CancellationToken ct)
    {
        if (permissions.Count > MeetingPermission.All.Count ||
            permissions.Any(x => !MeetingPermission.All.Contains(x, StringComparer.Ordinal)))
            throw new RequestFailureException(400, "Unknown meeting permission.");
        var requested = permissions.Distinct(StringComparer.Ordinal)
            .OrderBy(x => x, StringComparer.Ordinal).ToArray();

        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        await RequireRoleAsync(roleId, ct);
        var existing = await db.RoleClaims
            .Where(c => c.RoleId == roleId && c.ClaimType == MeetingPermission.ClaimType).ToListAsync(ct);
        db.RoleClaims.RemoveRange(existing);
        db.RoleClaims.AddRange(requested.Select(value => new IdentityRoleClaim<string>
        {
            RoleId = roleId, ClaimType = MeetingPermission.ClaimType, ClaimValue = value
        }));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return requested;
    }

    private async Task RequireRoleAsync(string roleId, CancellationToken ct)
    {
        if (!await access.IsCompanyAdminAsync(tenant.CompanyId, actor.EmployeeId, ct))
            throw new RequestFailureException(403, "A current company administrator is required.");
        if (!await db.Roles.AsNoTracking().AnyAsync(r => r.Id == roleId && r.CompanyId == tenant.CompanyId, ct))
            throw new RequestFailureException(404, "Role not found in this company.");
    }
}
