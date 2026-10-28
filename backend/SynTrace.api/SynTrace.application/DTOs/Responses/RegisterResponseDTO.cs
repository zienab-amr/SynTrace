using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.DTOs.Responses
{
    public class RegisterResponseDTO
    {
        public string EmployeeId { get; set; } = string.Empty;
        public string CompanyId { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;

    }
}
