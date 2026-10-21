using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Entities
{
    public class JiraConnection
    {
        
        public string Id { get; set; } = string.Empty;
        public string JiraAccountId { get; set; } = string.Empty;
        public string CloudId { get; set; } = string.Empty;
        public string SiteUrl { get; set; } = string.Empty;
        public string EncryptedAccessToken { get; set; } = string.Empty;
        public string? EncryptedRefreshToken { get; set; }
        public string ConnectedByEmployeeId { get; set; } = string.Empty;
        public JiraConnectionType JiraConnectionType { get; set; }
        public Employee ConnectedByEmployee { get; set; } = null!;
        public string CompanyId { get; set; } = string.Empty;
        public Company Company { get; set; } = null!;
        public bool status { get; set; } = true;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

    }
}
