using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories;

public sealed class EmployeeRepository(
    SynTraceDbContext db, UserManager<Employee> users, ICurrentTenant tenant,
    ICurrentEmployee actor, ProjectIntegrationAccess access) : IEmployeeRepository
{
    private IQueryable<Employee> CompanyEmployees => db.Employees.Where(e => e.CompanyId == tenant.CompanyId);
    private IQueryable<Role> CompanyRoles => db.Roles.Where(r => r.CompanyId == tenant.CompanyId);

    public async Task<IdentityResult> CreateEmployeeAsync(Employee employee, string password, string roleId)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        await RequireAdminAsync(employee);
        var role = await CompanyRoles.SingleOrDefaultAsync(r => r.Id == roleId)
            ?? throw new RequestFailureException(404, "Role was not found in this company.");

        if (await users.FindByNameAsync(employee.UserName!) is not null)
            throw new RequestFailureException(409, "An account already exists for this email.");

        var result = await users.CreateAsync(employee, password);
        if (!result.Succeeded)
            return result;

        db.UserRoles.Add(new IdentityUserRole<string> { UserId = employee.Id, RoleId = role.Id });
        await db.SaveChangesAsync();
        await transaction.CommitAsync();
        return result;
    }

    public async Task<IdentityResult> UpdateEmployeeAsync(Employee employee)
    {
        if (employee.CompanyId != tenant.CompanyId)
            throw new RequestFailureException(404, "Employee was not found.");

        if (employee.Id == actor.EmployeeId)
            return await users.UpdateAsync(employee);

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        await RequireAdminAsync(employee);
        var result = await users.UpdateAsync(employee);
        if (result.Succeeded)
            await transaction.CommitAsync();
        return result;
    }

    public async Task<IdentityResult> DeleteEmployeeAsync(Employee employee)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        await RequireAdminAsync(employee);
        if (await EmployeeRoles(employee.Id).AnyAsync(x => x.Role.NormalizedName == "ADMIN"))
            await RequireAnotherAdminAsync(employee.Id);

        try
        {
            var result = await users.DeleteAsync(employee);
            if (result.Succeeded)
                await transaction.CommitAsync();
            return result;
        }
        catch (DbUpdateException)
        {
            throw new RequestFailureException(409, "Remove the employee's dependent records before deleting this account.");
        }
    }

    public async Task ChangeEmployeeRole(Employee employee, string role, string? previousRoleId = null)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        await RequireAdminAsync(employee);
        var target = await ResolveRoleAsync(role)
            ?? throw new RequestFailureException(404, "Role was not found in this company.");
        var current = await EmployeeRoles(employee.Id).ToListAsync();
        var previous = previousRoleId is null
            ? current.Count <= 1 ? current.SingleOrDefault() : throw new RequestFailureException(400, "Choose which assigned role to replace.")
            : current.SingleOrDefault(x => x.Role.Id == previousRoleId)
                ?? throw new RequestFailureException(404, "The employee does not have the selected role.");

        if (previous?.Role.Id == target.Id)
            return;

        if (previous is not null)
        {
            if (previous.Role.NormalizedName == "ADMIN")
                await RequireAnotherAdminAsync(employee.Id);

            db.UserRoles.Remove(previous.Assignment);
        }

        if (current.All(x => x.Role.Id != target.Id))
            db.UserRoles.Add(new IdentityUserRole<string> { UserId = employee.Id, RoleId = target.Id });

        var result = await users.UpdateSecurityStampAsync(employee);
        if (!result.Succeeded)
            throw new RequestFailureException(409, "The employee changed. Refresh and try again.");

        var now = DateTime.UtcNow;
        await db.RefreshTokens.Where(x => x.EmployeeId == employee.Id && x.RevokedOn == null)
            .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.RevokedOn, now));
        await transaction.CommitAsync();
    }

    public Task<List<Employee>> GetAllEmployeesAsync() =>
        CompanyEmployees.AsNoTracking().OrderBy(e => e.FirstName).ThenBy(e => e.LastName).ThenBy(e => e.Id).ToListAsync();

    public Task<Employee?> GetEmployeeByIdAsync(string employeeId) =>
        CompanyEmployees.SingleOrDefaultAsync(e => e.Id == employeeId);

    public Task<List<Employee>> GetEmployeesByNameAsync(string name)
    {
        var normalized = name.Trim().ToUpperInvariant();
        return CompanyEmployees.AsNoTracking()
            .Where(e => e.FirstName.ToUpper().Contains(normalized) || e.LastName.ToUpper().Contains(normalized))
            .OrderBy(e => e.FirstName).ThenBy(e => e.LastName).ThenBy(e => e.Id).ToListAsync();
    }

    public async Task<IList<Employee>> GetEmployeesByRoleAsync(string role)
    {
        var target = await ResolveRoleAsync(role);
        if (target is null)
            return [];

        return await (from employee in CompanyEmployees.AsNoTracking()
                      join assignment in db.UserRoles on employee.Id equals assignment.UserId
                      where assignment.RoleId == target.Id
                      orderby employee.FirstName, employee.LastName, employee.Id
                      select employee).ToListAsync();
    }

    public async Task<ILookup<string, Role>> GetRolesForEmployeesAsync(string[] employeeIds)
    {
        var roles = await (from employee in CompanyEmployees.AsNoTracking()
                           join assignment in db.UserRoles on employee.Id equals assignment.UserId
                           join role in CompanyRoles.AsNoTracking() on assignment.RoleId equals role.Id
                           where employeeIds.Contains(employee.Id)
                           orderby role.NormalizedName
                           select new { employee.Id, Role = role }).ToListAsync();
        return roles.ToLookup(x => x.Id, x => x.Role);
    }

    private async Task<Role?> ResolveRoleAsync(string role)
    {
        var byId = await CompanyRoles.AsNoTracking().SingleOrDefaultAsync(x => x.Id == role);
        if (byId is not null)
            return byId;

        var normalized = users.NormalizeName(role.Trim());
        return await CompanyRoles.AsNoTracking().SingleOrDefaultAsync(x => x.NormalizedName == normalized);
    }

    private IQueryable<EmployeeRole> EmployeeRoles(string employeeId) =>
        from assignment in db.UserRoles
        join role in CompanyRoles on assignment.RoleId equals role.Id
        where assignment.UserId == employeeId
        select new EmployeeRole { Assignment = assignment, Role = role };

    private async Task RequireAdminAsync(Employee employee)
    {
        if (employee.CompanyId != tenant.CompanyId ||
            !await access.IsCompanyAdminAsync(tenant.CompanyId, actor.EmployeeId, CancellationToken.None))
            throw new RequestFailureException(403, "A current company administrator is required.");
    }

    private async Task RequireAnotherAdminAsync(string employeeId)
    {
        var exists = await (from employee in CompanyEmployees
                            join assignment in db.UserRoles on employee.Id equals assignment.UserId
                            join role in CompanyRoles on assignment.RoleId equals role.Id
                            where employee.Id != employeeId && role.NormalizedName == "ADMIN"
                            select employee.Id).AnyAsync();
        if (!exists)
            throw new RequestFailureException(409, "The company must keep at least one administrator.");
    }

    private sealed class EmployeeRole
    {
        public required IdentityUserRole<string> Assignment { get; init; }
        public required Role Role { get; init; }
    }
}
