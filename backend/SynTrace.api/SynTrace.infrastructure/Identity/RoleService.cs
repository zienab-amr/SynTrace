using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;


namespace SynTrace.Infrastructure.Identity
{
    public class RoleService : IRoleService
    {
        private readonly RoleManager<Role> _roleManager;
        private readonly UserManager<Employee> _userManager;
        private readonly ICurrentTenant _currentTenant;
        private readonly ITenantValidator _tenantValidator;
        private readonly SynTraceDbContext _context;

        public RoleService(
            RoleManager<Role> roleManager,
            UserManager<Employee> userManager,
            ICurrentTenant currentTenant,
            ITenantValidator tenantValidator,
            SynTraceDbContext context)
        {
            _roleManager = roleManager;
            _userManager = userManager;
            _currentTenant = currentTenant;
            _tenantValidator = tenantValidator;
            _context = context;
        }
        public async Task<IdentityResult> AssignRoleAsync(Employee employee, string roleId)
        {
            if (!_tenantValidator.BelongsToCurrentTenant(employee.CompanyId))
                throw new UnauthorizedAccessException(
                    "Employee does not belong to the current tenant.");

            var existingRole = await _roleManager.FindByIdAsync(roleId);

            if (existingRole == null ||
                existingRole.CompanyId != _currentTenant.CompanyId)
            {
                throw new InvalidOperationException(
                    "Role does not exist for the current tenant.");
            }

            var alreadyAssigned = await _context.UserRoles
                .AnyAsync(x => x.UserId == employee.Id && x.RoleId == roleId);

            if (alreadyAssigned)
                throw new InvalidOperationException("Employee already has this role.");

            _context.UserRoles.Add(new IdentityUserRole<string>
            {
                UserId = employee.Id,
                RoleId = roleId
            });

            await _context.SaveChangesAsync();

            return IdentityResult.Success;
        }

        public async Task<IdentityResult> CreateRoleAsync(string role)
        {
            if (string.IsNullOrWhiteSpace(role))
                throw new ArgumentException("Role name is required.");

            var companyId = _currentTenant.CompanyId;

            if (string.IsNullOrWhiteSpace(companyId))
                throw new InvalidOperationException(
                    "Current tenant's company ID is not set.");

            var existingRole = await GetRoleByNameAsync(role);

            if (existingRole != null)
                throw new InvalidOperationException(
                    "Role already exists for the current tenant.");

            var newRole = new Role
            {
                Name = role.Trim(),
                CompanyId = companyId
            };

            return await _roleManager.CreateAsync(newRole);
        }

        public async Task<List<Role>> GetAllRolesAsync()
        {
            var companyId = _currentTenant.CompanyId;
            if(companyId is null)
                throw new InvalidOperationException("Current tenant's company ID is not set.");


            return await _roleManager.Roles
                .Where(r => r.CompanyId == companyId)
                .ToListAsync();

        }

        public async Task<Role?> GetRoleByNameAsync(string role)
        {
            if (string.IsNullOrWhiteSpace(role))
                return null;

            var companyId = _currentTenant.CompanyId;

            var normalizedName = _roleManager.NormalizeKey(role.Trim());

            return await _roleManager.Roles
                .FirstOrDefaultAsync(r =>
                    r.CompanyId == companyId &&
                    r.NormalizedName == normalizedName);
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
            var companyId = _currentTenant.CompanyId;

            if (string.IsNullOrWhiteSpace(companyId))
                throw new InvalidOperationException("Current tenant's company ID is not set.");

            if (string.IsNullOrWhiteSpace(newRoleName))
                throw new ArgumentException("New role name is required.");

            var roleExisting = await GetRoleByNameAsync(newRoleName);

            if (roleExisting == null)
                throw new Exception("This role was not found.");

            var existingNewRole = await _roleManager.FindByNameAsync(newRoleName);

            if (existingNewRole != null &&
                existingNewRole.Id != roleExisting.Id)
            {
                throw new InvalidOperationException(
                    "Role already exists for the current tenant.");
            }

            roleExisting.Name = newRoleName.Trim();

            return await _roleManager.UpdateAsync(roleExisting);
        }
    }
}
