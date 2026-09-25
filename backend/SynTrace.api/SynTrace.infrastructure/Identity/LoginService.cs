using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity
{
    public class LoginService : ILoginService
    {
        private readonly UserManager<Employee> _userManager;
        private readonly SignInManager<Employee> _signInManager;
        private readonly ITokenService _token;
        public LoginService(UserManager<Employee> userManager, SignInManager<Employee> signInManager,ITokenService token)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _token = token;
        }
        public async Task<TokenResultDTO> GetEmployeeByEmail(LoginRequestDTO requestDTO)
        {
            var existingEmployee = await _userManager.FindByEmailAsync(requestDTO.Email);

            if(existingEmployee == null)
                throw new Exception("Employee not found");

            var result = await _signInManager.CheckPasswordSignInAsync(existingEmployee, requestDTO.Password, false);

            if(!result.Succeeded)
                throw new Exception("Invalid password");

            return await _token.GenerateTokens(existingEmployee);
        }
    }
}
