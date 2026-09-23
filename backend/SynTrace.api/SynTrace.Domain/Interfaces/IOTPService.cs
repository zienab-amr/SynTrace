using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;

namespace SynTrace.Domain.Interfaces
{
    public interface IOTPService
    {
        public string GenerateOTP();

        public Task SendOTP(OTPRequestDTO request);

        public bool ValidateOTP(VerifyOTPRequestDTO verifyOTP);
    }
}
