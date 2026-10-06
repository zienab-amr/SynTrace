using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.DTOs.Responses
{
    public class RegisterResponseDTO
    {
        public string EmployeeId { get; set; } = string.Empty;
        public Guid CompanyId { get; set; } = Guid.NewGuid();
        public string Email { get; set; } = string.Empty;

    }
}
