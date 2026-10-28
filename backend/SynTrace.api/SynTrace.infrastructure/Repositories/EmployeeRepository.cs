using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.ExternalServices;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories
{
    public class EmployeeRepository : IEmployeeRepository
    {
        private readonly SynTraceDbContext _context;
        private readonly UserManager<Employee> _userManager;
        private readonly ICurrentTenant _currentTenant;
        public EmployeeRepository(SynTraceDbContext context, UserManager<Employee> userManager, ICurrentTenant currentTenant)
        {
            _context = context;
            _userManager = userManager;
            _currentTenant = currentTenant;
        }

        public async Task<IdentityResult> CreateEmployeeAsync(Employee employee, string password) => await _userManager.CreateAsync(employee, password);
        public async Task<IdentityResult> UpdateEmployeeAsync(Employee employee) => await _userManager.UpdateAsync(employee);
        public async Task<IdentityResult> DeleteEmployeeAsync(Employee employee) => await _userManager.DeleteAsync(employee);

        public async Task<IdentityResult> ChangeEmployeeRole(Employee employee, string oldRole, string newRole)
        {
            var removeResult = await _userManager.RemoveFromRoleAsync(employee, oldRole);
            if (!removeResult.Succeeded)
                return removeResult;

            return await _userManager.AddToRoleAsync(employee, newRole);
        }


        public async Task<List<Employee>> GetAllEmployeesAsync() => await _context.Employees
                                                                             .Where(e => e.CompanyId == _currentTenant.CompanyId)
                                                                             .ToListAsync();

        public async Task<Employee?> GetEmployeeByIdAsync(string employeeId) => await _context.Employees
                                                                                                .FirstOrDefaultAsync(e => 
                                                                                                e.Id == employeeId && 
                                                                                                e.CompanyId == _currentTenant.CompanyId);

        public async Task<List<Employee>> GetEmployeesByNameAsync(string name) => await _context.Employees
                                                                                            .Where(e =>
                                                                                                e.CompanyId == _currentTenant.CompanyId &&
                                                                                                (e.FirstName.ToLower().Contains(name.ToLower())
                                                                                                 || e.LastName.ToLower().Contains(name.ToLower())))
                                                                                            .ToListAsync();

        public async Task<IList<Employee>> GetEmployeesByRoleAsync(string role)
        {
            var employees = await _userManager.GetUsersInRoleAsync(role);

            return employees
                .Where(e => e.CompanyId == _currentTenant.CompanyId)
                .ToList();
        }

        public async Task<Employee?> GetEmployeeByEmailAsync(string email)
        {
            return await _context.Employees
                .FirstOrDefaultAsync(e =>
                    e.Email == email &&
                    e.CompanyId == _currentTenant.CompanyId);
        }
        // اجيب الموظفين اللي تحت تيم ليدر معين 
        // التيم اللي ماسك بروجيكت كذا

    }
}
