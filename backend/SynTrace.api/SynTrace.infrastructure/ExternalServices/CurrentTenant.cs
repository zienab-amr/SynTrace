
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

        public string CompanyId
        {
            get
            {
                var claim = _httpContextAccessor.HttpContext?
                    .User
                    .FindFirst("CompanyId");

                if (string.IsNullOrWhiteSpace(claim?.Value))
                    throw new UnauthorizedAccessException(
                        "Valid CompanyId claim not found.");

                return claim.Value;
            }
        }
    }
}
