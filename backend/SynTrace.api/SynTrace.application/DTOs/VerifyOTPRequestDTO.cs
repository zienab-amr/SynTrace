using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.DTOs
{
    public class VerifyOTPRequestDTO
    {
        public string Email { get; set; } = string.Empty;
        public string OTP { get; set; } = string.Empty;
    }
}
