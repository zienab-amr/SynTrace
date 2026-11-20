using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity;

namespace SynTrace.Domain.Entities
{
    public class Role : IdentityRole
    {
        public string CompanyId { get; set; }
        public Company Company { get; set; }
    }
}
