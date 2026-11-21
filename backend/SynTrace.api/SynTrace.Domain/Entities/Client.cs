using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Entities
{
    public class Client : ITenantOwned
    {
        public string ClientId { get; set; } = Guid.NewGuid().ToString();
        public string ClientName { get; set; } = null!;
        public string? PhoneNumber { get; set; }
        public string? Email { get; set; }
        public ClientStatus Status { get; set; } = ClientStatus.Active;

        public string CompanyId { get; set; } 
        public Company Company { get; set; } = null!;

        public ICollection<Project> Projects { get; set; } = new List<Project>();
    }
}
