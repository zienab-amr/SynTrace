using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities
{
    public class Company
    {
        public string CompanyId { get; set; } = string.Empty;
        public string CompanyName { get; set; }

        public ICollection<Employee> Employees { get; set; } = new List<Employee>();
    }
}
