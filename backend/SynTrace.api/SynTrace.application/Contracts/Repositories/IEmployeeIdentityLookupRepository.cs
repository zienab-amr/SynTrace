using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Contracts.Repositories;

/// <summary>Tenant-scoped, read-only identity resolution for the internal AI service.</summary>
public interface IEmployeeIdentityLookupRepository
{
    Task<IReadOnlyList<InternalEmployeeIdentityDTO>> GetCompanyIdentitiesAsync(
        string companyId,
        CancellationToken cancellationToken);
}
