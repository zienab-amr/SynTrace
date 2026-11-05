using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.Contracts.Auth
{
    public interface ITenantValidator
    {
        public bool BelongsToCurrentTenant(string companyId);
    }
}
