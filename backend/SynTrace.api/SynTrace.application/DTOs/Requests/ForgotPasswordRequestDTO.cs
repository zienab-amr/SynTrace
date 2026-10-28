using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.DTOs.Requests
{
    public class ForgotPasswordRequestDTO
    {
        public string Email { get; set; }
        public string OTP { get; set; }
        public string NewPassword { get; set; }
        public string ConfirmPassword { get; set; }
    }
}
