using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Http;
using SynTrace.Application.Contracts;

namespace SynTrace.Infrastructure.ExternalServices
{
    public class CurrentTenant : ICurrentTenant
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        public CurrentTenant(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }
        public Guid CompanyId
        {
            get
            {
                var claim = _httpContextAccessor.HttpContext?
                    .User
                    .FindFirst("CompanyId");

                if (claim == null)
                    throw new UnauthorizedAccessException("CompanyId claim not found.");

                return Guid.Parse(claim.Value);
            }
        }


    }
}
