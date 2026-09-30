using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;
using SynTrace.Domain.Entities;

namespace SynTrace.Domain.Interfaces
{
    public interface IEmployeeRepository
    {
        public Task<IdentityResult> CreateEmployeeAsync(Employee employee, string password);
        public Task<IdentityResult> UpdateEmployeeAsync(Employee employee);
        public Task<IdentityResult> DeleteEmployeeAsync(Employee employee);
        public Task<IdentityResult> ChangeEmployeeRole(Employee employee, string oldRole, string newRole);


        public Task<List<Employee>> GetAllEmployeesAsync();
        public Task<Employee?> GetEmployeeByIdAsync(string employeeId);
        public Task<List<Employee>> GetEmployeesByNameAsync(string name);
        public Task<IList<Employee>> GetEmployeesByRoleAsync(string role);
        public Task<Employee?> GetEmployeeByEmailAsync(string email);


    }
}
