using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Http;
using SynTrace.Application.Contracts;

namespace SynTrace.Infrastructure.ExternalServices
{
    public class CurrentEmployee : ICurrentEmployee
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        public CurrentEmployee(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }
        public string EmployeeId { get
            {
                var claim = _httpContextAccessor.HttpContext?
                    .User?
                    .FindFirst(ClaimTypes.NameIdentifier)?
                    .Value;

                if (string.IsNullOrWhiteSpace(claim))
                    throw new UnauthorizedAccessException(
                        "EmployeeId claim not found.");

                return claim;
            } }
    }
}
