using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.DTOs;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Infrastructure.Identity
{
    public class ForgotPasswordService : IForgotPasswordService
    {
        private readonly UserManager<Employee> _userManager;
        private readonly IOTPService _oTPService;

        public ForgotPasswordService(UserManager<Employee> userManager, IOTPService oTPService)
        {
            _userManager = userManager;
            _oTPService = oTPService;
        }
        public async Task ForgotPasswordAsync(ForgotPasswordRequestDTO forgotPassword) 
        {
            var employee = await _userManager.FindByEmailAsync(forgotPassword.Email);

            if (employee == null)
                throw new Exception("If the account exists, a verification code has been sent.");

            if (forgotPassword.NewPassword != forgotPassword.ConfirmPassword)
                throw new InvalidOperationException(
                    "Password confirmation does not match.");

            if(!_oTPService.IsEmailVerified(forgotPassword.Email))
                throw new InvalidOperationException(
                    "Email is not verified.");

            var token = await _userManager.GeneratePasswordResetTokenAsync(employee);
            var reset = await _userManager.ResetPasswordAsync(employee, token, forgotPassword.NewPassword);

            if (!reset.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", reset.Errors.Select(e => e.Description)));
            }

            _oTPService.RemoveEmailVerification(forgotPassword.Email);

            return;
        }
    }
}
