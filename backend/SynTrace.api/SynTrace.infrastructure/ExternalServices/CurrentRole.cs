using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Http;
using SynTrace.Application.Contracts;

namespace SynTrace.Infrastructure.ExternalServices
{
    public class CurrentRole : ICurrentRole
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public CurrentRole(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }
        public string[] Role
        {
            get
            {
                var roles= _httpContextAccessor.HttpContext?
                    .User?
                    .FindAll(ClaimTypes.Role);
                return roles?.Select(r => r.Value).ToArray() ?? Array.Empty<string>();
            }
        }
    }
}
