using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity;

public sealed class TenantRoleValidator(SynTraceDbContext db) : IRoleValidator<Role>
{
    public async Task<IdentityResult> ValidateAsync(RoleManager<Role> manager, Role role)
    {
        if (string.IsNullOrWhiteSpace(role.CompanyId) || string.IsNullOrWhiteSpace(role.Name) || role.Name.Length > 256)
            return IdentityResult.Failed(new IdentityError { Code = "InvalidRole", Description = "A valid role name is required." });

        var normalizedName = manager.NormalizeKey(role.Name);
        if (await db.Roles.AnyAsync(r =>
                r.CompanyId == role.CompanyId && r.NormalizedName == normalizedName && r.Id != role.Id))
            return IdentityResult.Failed(new IdentityError
            {
                Code = "DuplicateRole", Description = "This role already exists for this company."
            });

        return IdentityResult.Success;
    }
}
