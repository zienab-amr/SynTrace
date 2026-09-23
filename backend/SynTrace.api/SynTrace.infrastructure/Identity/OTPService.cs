using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Caching.Memory;
using SynTrace.Application.DTOs;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Infrastructure.Identity
{
    public class OTPService
    {
        private readonly IMemoryCache _cache;
        private readonly UserManager<Employee> _userManager;
        private readonly IEmailService _emailService;

        public OTPService(
            IMemoryCache cache,
            UserManager<Employee> userManager,
            IEmailService emailService)
        {
            _cache = cache;
            _userManager = userManager;
            _emailService = emailService;
        }

        public string GenerateOTP()
        {
            return RandomNumberGenerator
                .GetInt32(100000, 1000000)
                .ToString();
        }

        public async Task SendOTP(OTPRequestDTO request)
        {
            var existingEmail =
                await _userManager.FindByEmailAsync(request.Email);

            if (existingEmail != null)
                throw new InvalidOperationException("Email already exists.");

            var otp = GenerateOTP();

            _cache.Set(
                $"OTP:{request.Email}",
                otp,
                TimeSpan.FromMinutes(5));

            await _emailService.SendOTP(request.Email, otp);
        }

        public bool ValidateOTP(VerifyOTPRequestDTO verifyOTP)
        {
            var key = $"OTP:{verifyOTP.Email}";

            if (_cache.TryGetValue(key, out string? cachedOtp))
            {
                if (cachedOtp == verifyOTP.OTP)
                {
                    _cache.Remove(key);
                    return true;
                }
            }

            return false;
        }
    }
}