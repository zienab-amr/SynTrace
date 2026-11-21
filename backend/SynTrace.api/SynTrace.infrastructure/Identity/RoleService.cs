using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity;

public sealed class RoleService(RoleManager<Role> roles, ICurrentTenant tenant, ICurrentEmployee actor,
    ProjectIntegrationAccess access, SynTraceDbContext db) : IRoleService
{
    private IQueryable<Role> CompanyRoles => roles.Roles.Where(r => r.CompanyId == tenant.CompanyId);

    public async Task<IdentityResult> CreateRoleAsync(string name)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        await RequireAdminAsync();
        if (await GetRoleByNameAsync(name) is not null)
            throw new RequestFailureException(409, "A role with this name already exists.");

        var result = await roles.CreateAsync(new Role { Name = name.Trim(), CompanyId = tenant.CompanyId });
        if (result.Succeeded)
            await transaction.CommitAsync();

        return result;
    }

    public Task<List<Role>> GetAllRolesAsync() =>
        CompanyRoles.AsNoTracking().OrderBy(r => r.NormalizedName).ToListAsync();

    public Task<Role?> GetRoleByNameAsync(string name)
    {
        var normalized = roles.NormalizeKey(name.Trim());
        return CompanyRoles.SingleOrDefaultAsync(r => r.NormalizedName == normalized);
    }

    public async Task DeleteRoleAsync(string? roleId, string? legacyName)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        await RequireAdminAsync();
        var role = await GetModifiableRoleAsync(roleId, legacyName);
        if (await db.UserRoles.AnyAsync(x => x.RoleId == role.Id))
            throw new RequestFailureException(409, "Reassign employees before deleting this role.");

        EnsureSuccess(await roles.DeleteAsync(role));
        await transaction.CommitAsync();
    }

    public async Task UpdateRoleAsync(string? roleId, string? legacyName, string newName)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        await RequireAdminAsync();
        var role = await GetModifiableRoleAsync(roleId, legacyName);
        var existing = await GetRoleByNameAsync(newName);
        if (existing is not null && existing.Id != role.Id)
            throw new RequestFailureException(409, "A role with this name already exists.");

        role.Name = newName.Trim();
        EnsureSuccess(await roles.UpdateAsync(role));
        await transaction.CommitAsync();
    }

    private async Task<Role> GetModifiableRoleAsync(string? roleId, string? legacyName)
    {
        if (string.IsNullOrWhiteSpace(roleId) && string.IsNullOrWhiteSpace(legacyName))
            throw new RequestFailureException(400, "RoleId is required.");

        var role = roleId is null
            ? await GetRoleByNameAsync(legacyName!)
            : await CompanyRoles.SingleOrDefaultAsync(x => x.Id == roleId);

        if (role is null)
            throw new RequestFailureException(404, "Role was not found in this company.");

        if (role.NormalizedName == "ADMIN")
            throw new RequestFailureException(409, "The company administrator role is reserved.");

        return role;
    }

    private async Task RequireAdminAsync()
    {
        if (!await access.IsCompanyAdminAsync(tenant.CompanyId, actor.EmployeeId, CancellationToken.None))
            throw new RequestFailureException(403, "A current company administrator is required.");
    }

    private static void EnsureSuccess(IdentityResult result)
    {
        if (!result.Succeeded)
            throw new RequestFailureException(409, string.Join(" ", result.Errors.Select(error => error.Description)));
    }
}
