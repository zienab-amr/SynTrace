using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities
{
    public class RefreshToken
    {
        public string Id { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;

        public DateTime CreatedOn { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedOn { get; set; } = DateTime.UtcNow;
        public DateTime ExpiredDate { get; set; }
        public DateTime? RevokedOn { get; set; }

        public string EmployeeId { get; set; } = string.Empty;
        public Employee? Employee { get; set; }

        public bool IsExpired => DateTime.UtcNow >= ExpiredDate;
        public bool IsRevoked => RevokedOn != null;
    }
}
