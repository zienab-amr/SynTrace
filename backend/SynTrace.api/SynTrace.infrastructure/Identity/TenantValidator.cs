using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Infrastructure.Identity
{
    public class TenantValidator : ITenantValidator
    {
        private readonly ICurrentTenant _currentTenant;
        public TenantValidator(ICurrentTenant currentTenant)
        {
            _currentTenant = currentTenant;
        }
        public bool BelongsToCurrentTenant(string companyId)
        {
            return !string.IsNullOrWhiteSpace(companyId)
                && !string.IsNullOrWhiteSpace(_currentTenant.CompanyId)
                && string.Equals(
                    _currentTenant.CompanyId,
                    companyId,
                    StringComparison.Ordinal
                );
        }
    }
}
