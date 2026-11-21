using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Enums;

namespace SynTrace.Application.DTOs.Requests
{
    public class ClientRequestDTO
    {
        public string ClientName { get; set; } = null!;
        public string? PhoneNumber { get; set; }
        public string? Email { get; set; }
        public ClientStatus Status { get; set; } = ClientStatus.Active;

    }
}
