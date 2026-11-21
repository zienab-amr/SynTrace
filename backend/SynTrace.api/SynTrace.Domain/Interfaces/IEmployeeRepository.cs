using Microsoft.AspNetCore.Identity;
using SynTrace.Domain.Entities;

namespace SynTrace.Domain.Interfaces;

public interface IEmployeeRepository
{
    Task<IdentityResult> CreateEmployeeAsync(Employee employee, string password, string roleId);
    Task<IdentityResult> UpdateEmployeeAsync(Employee employee);
    Task<IdentityResult> DeleteEmployeeAsync(Employee employee);
    Task ChangeEmployeeRole(Employee employee, string role, string? previousRoleId = null);
    Task<List<Employee>> GetAllEmployeesAsync();
    Task<Employee?> GetEmployeeByIdAsync(string employeeId);
    Task<List<Employee>> GetEmployeesByNameAsync(string name);
    Task<IList<Employee>> GetEmployeesByRoleAsync(string role);
    Task<ILookup<string, Role>> GetRolesForEmployeesAsync(string[] employeeIds);
}
