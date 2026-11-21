using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities
{
    public class EmployeeProject : ITenantOwned
    {
        public string EmployeeProjectId { get; set; } = Guid.NewGuid().ToString();
        public string Role { get; set; } = null!;


        public string CompanyId { get; set; }
        public Company Company { get; set; } = null!;

        public string EmployeeId { get; set; }
        public Employee Employee { get; set; } = null!;

        public string ProjectId { get; set; }
        public Project Project { get; set; } = null!;


    }
}
