using System.Security.Cryptography;
using Azure.Core;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Caching.Memory;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Infrastructure.Identity
{
    public class OTPService : IOTPService
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

        public async Task SendOTP(OTPRequestDTO requestDto)
        {
            var otp = GenerateOTP();

            _cache.Set(
                $"OTP:{requestDto.Email}",
                otp,
                TimeSpan.FromMinutes(5));

            await _emailService.SendOTP(requestDto.Email, otp);
        }

        public async Task<bool> VerifyOTP(VerifyOTPRequestDTO requestDto)
        {
            var key = $"OTP:{requestDto.Email}";

            if (_cache.TryGetValue(key, out string? cachedOtp))
            {
                if (cachedOtp == requestDto.OTP)
                {
                    _cache.Remove(key);

                    _cache.Set($"Verified:{requestDto.Email}", true, TimeSpan.FromMinutes(10));

                    return true;
                }
            }
            return false;
        }

        public bool IsEmailVerified(string email)
        {
            return _cache.TryGetValue($"Verified:{email}", out bool isVerified) && isVerified;

        }

        public void RemoveEmailVerification(string email)
        {
            _cache.Remove($"Verified:{email}");
        }

    }
}