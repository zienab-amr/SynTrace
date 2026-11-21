using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Infrastructure.Identity;

public sealed class LoginService(
    UserManager<Employee> users, SignInManager<Employee> signInManager, ITokenService tokens) : ILoginService
{
    public async Task<TokenResultDTO> GetEmployeeByEmail(LoginRequestDTO request)
    {
        var employee = await users.FindByNameAsync(request.Email.Trim());
        if (employee is null)
            throw new RequestFailureException(401, "Invalid email or password.");

        var result = await signInManager.CheckPasswordSignInAsync(employee, request.Password, lockoutOnFailure: true);
        if (!result.Succeeded)
            throw new RequestFailureException(401, "Invalid email or password.");

        return await tokens.GenerateTokens(employee);
    }
}
