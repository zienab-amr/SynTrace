using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.DTOs
{
    public class RegisterRequestDTO
    {
        public string CompanyName { get; set; } = string.Empty;

        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string? PhoneNumber { get; set; }

        public string Password { get; set; } = string.Empty;

        public string OTP { get; set; } = string.Empty;

    }
}
