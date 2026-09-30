using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.Contracts
{
    public interface ICurrentTenant
    {
        public Guid CompanyId { get;} 

    }
}
