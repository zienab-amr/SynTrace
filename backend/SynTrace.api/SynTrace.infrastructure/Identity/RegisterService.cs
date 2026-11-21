using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity;

public sealed class RegisterService(
    SynTraceDbContext db, UserManager<Employee> users, IOTPService codes, RoleManager<Role> roles) : IRegisterService
{
    public async Task<RegisterResponseDTO> CreateFirstEmployeeAsync(RegisterRequestDTO request)
    {
        var email = request.Email.Trim();
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        if (!await codes.ConsumeRegistrationAsync(email, request.VerificationToken, request.OTP))
        {
            await transaction.CommitAsync();
            throw new RequestFailureException(400, "Valid email verification is required.");
        }

        if (await users.FindByNameAsync(email) is not null)
            throw new RequestFailureException(409, "An account already exists for this email.");

        var company = new Company { CompanyId = Guid.NewGuid().ToString(), CompanyName = request.CompanyName.Trim() };
        db.Companies.Add(company);
        var employee = new Employee
        {
            FirstName = request.FirstName.Trim(), LastName = request.LastName.Trim(),
            Email = email, UserName = email, PhoneNumber = request.PhoneNumber,
            EmailConfirmed = true, Company = company, LockoutEnabled = true
        };
        EnsureSuccess(await users.CreateAsync(employee, request.Password));

        var admin = new Role { Name = "Admin", CompanyId = company.CompanyId };
        EnsureSuccess(await roles.CreateAsync(admin));
        db.UserRoles.Add(new IdentityUserRole<string> { UserId = employee.Id, RoleId = admin.Id });
        await db.SaveChangesAsync();
        await transaction.CommitAsync();

        return new RegisterResponseDTO { EmployeeId = employee.Id, CompanyId = company.CompanyId, Email = employee.Email };
    }

    private static void EnsureSuccess(IdentityResult result)
    {
        if (!result.Succeeded)
            throw new RequestFailureException(400, string.Join(" ", result.Errors.Select(error => error.Description)));
    }
}
