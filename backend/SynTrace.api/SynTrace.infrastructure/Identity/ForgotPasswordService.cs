using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity;

public sealed class ForgotPasswordService(
    UserManager<Employee> users, IOTPService codes, SynTraceDbContext db) : IForgotPasswordService
{
    public async Task ForgotPasswordAsync(ForgotPasswordRequestDTO request)
    {
        if (request.NewPassword != request.ConfirmPassword)
            throw new RequestFailureException(400, "Password confirmation does not match.");

        var email = request.Email.Trim();
        var normalized = users.NormalizeEmail(email);
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var candidates = await db.Employees.AsNoTracking().Where(x => x.NormalizedEmail == normalized)
            .Take(2).ToListAsync();
        if (candidates.Count != 1 || !await codes.ConsumePasswordResetAsync(email, candidates[0].Id, request.OTP))
        {
            await transaction.CommitAsync();
            throw new RequestFailureException(400, "Invalid or expired password reset code.");
        }

        var employee = await users.FindByIdAsync(candidates[0].Id);
        if (employee is null || employee.NormalizedEmail != normalized)
            throw new RequestFailureException(400, "Invalid or expired password reset code.");

        var token = await users.GeneratePasswordResetTokenAsync(employee);
        var reset = await users.ResetPasswordAsync(employee, token, request.NewPassword);
        if (!reset.Succeeded)
            throw new RequestFailureException(400, string.Join(" ", reset.Errors.Select(error => error.Description)));

        var now = DateTime.UtcNow;
        await db.RefreshTokens.Where(x => x.EmployeeId == employee.Id && x.RevokedOn == null)
            .ExecuteUpdateAsync(update => update
                .SetProperty(x => x.RevokedOn, now)
                .SetProperty(x => x.UpdatedOn, now));
        await transaction.CommitAsync();
    }
}
