using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Entities
{
    public class JiraOAuthState
    {
        public string JiraOAuthStateId { get; set; } = string.Empty;
        public string StateHash { get; set; } = string.Empty;
        public string EmployeeId { get; set; } = string.Empty;
        public Employee Employee { get; set; } = null!;
        public string CompanyId { get; set; } = string.Empty;
        public Company Company { get; set; } = null!;
        public JiraConnectionType ConnectionType { get; set; }
        public DateTime ExpiresAt { get; set; }
        public DateTime? ConsumedAt { get; set; }
    }
}
