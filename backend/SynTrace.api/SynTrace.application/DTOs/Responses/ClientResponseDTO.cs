using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Enums;

namespace SynTrace.Application.DTOs.Responses
{
    public class ClientResponseDTO
    {
        public string ClientId { get; set; } = null!;
        public string ClientName { get; set; } = null!;
        public string? PhoneNumber { get; set; }
        public string? Email { get; set; }
        public ClientStatus Status { get; set; } = ClientStatus.Active;
    }
}
