using Microsoft.AspNetCore.Identity;
using SynTrace.Domain.Entities;

namespace SynTrace.Application.Contracts.Auth;

public interface IRoleService
{
    Task<IdentityResult> CreateRoleAsync(string name);
    Task<List<Role>> GetAllRolesAsync();
    Task<Role?> GetRoleByNameAsync(string name);
    Task DeleteRoleAsync(string? roleId, string? legacyName);
    Task UpdateRoleAsync(string? roleId, string? legacyName, string newName);
}
