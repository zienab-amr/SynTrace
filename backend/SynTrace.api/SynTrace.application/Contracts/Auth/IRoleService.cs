using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Domain.Entities;

namespace SynTrace.Application.Contracts.Auth
{
    public interface IRoleService
    {
        public Task<IdentityResult> AssignRoleAsync(Employee employee, string role);
        public Task<IdentityResult> CreateRoleAsync(string role);
        public Task<List<Role>> GetAllRolesAsync();
        public Task<Role?> GetRoleByNameAsync(string role);
        public Task<IdentityResult> DeleteRoleAsync(string role);
        public Task<IdentityResult> UpdateRoleAsync(string oldRoleName, string newRoleName);
    }
}

        
