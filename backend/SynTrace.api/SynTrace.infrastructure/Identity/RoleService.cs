using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Domain.Entities;
using Microsoft.EntityFrameworkCore;


namespace SynTrace.Infrastructure.Identity
{
    public class RoleService : IRoleService
    {
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly UserManager<Employee> _userManager;
        public RoleService(RoleManager<IdentityRole> roleManager, UserManager<Employee> userManager)
        {
            _roleManager = roleManager;
            _userManager = userManager;
        }
        public async Task<IdentityResult> AssignRoleAsync(Employee employee, string role)
        {
            return await _userManager.AddToRoleAsync(employee, role);
        }

        public async Task<IdentityResult> CreateRoleAsync(string role)
        {
            var newRole = new IdentityRole
            {
                Name = role
            };
            return await _roleManager.CreateAsync(newRole);
        }

        public async Task<List<IdentityRole>> GetAllRolesAsync()
        {
            return await _roleManager.Roles.ToListAsync();
        }

        public async Task<IdentityRole?> GetRoleByNameAsync(string role)
        {
            return await _roleManager.FindByNameAsync(role);
        }

        public async Task<IdentityResult> DeleteRoleAsync(string role)
        {
            var roleExisting = await GetRoleByNameAsync(role);

            if (roleExisting == null)
                throw new Exception("This Role not found");

            return await _roleManager.DeleteAsync(roleExisting);
        }

        public async Task<IdentityResult> UpdateRoleAsync(string oldRoleName, string newRoleName)
        {
            var roleExisting = await GetRoleByNameAsync(oldRoleName);

            if (roleExisting == null)
                throw new Exception("This role was not found.");

            roleExisting.Name = newRoleName;

            return await _roleManager.UpdateAsync(roleExisting);
        }
    }
}
