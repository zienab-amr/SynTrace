using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity
{
    public class LoginService
    {
        private readonly UserManager<Employee> _userManager;
        private readonly SignInManager<Employee> _signInManager;
        private readonly IToken _token;
        public LoginService(UserManager<Employee> userManager, SignInManager<Employee> signInManager,IToken token)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _token = token;
        }
        public async Task<string> GetEmployeeByEmail(string email, string password)
        {
            var existingEmployee = await _userManager.FindByEmailAsync(email);

            if(existingEmployee == null)
                throw new Exception("Employee not found");

            var result = await _signInManager.CheckPasswordSignInAsync(existingEmployee, password, false);

            if(!result.Succeeded)
                throw new Exception("Invalid password");

            var token = await _token.GenerateToken(existingEmployee);

            return token;
        }
    }
}
