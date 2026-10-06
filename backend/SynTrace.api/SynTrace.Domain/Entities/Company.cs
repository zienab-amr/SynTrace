using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities
{
    public class Company
    {
        public Guid CompanyId { get; set; } = Guid.NewGuid();
        public string CompanyName { get; set; }

        public ICollection<Employee> Employees { get; set; } = new List<Employee>();
    }
}
