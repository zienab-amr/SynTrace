using MediatR;
using SynTrace.Application.Contracts.Repositories;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Integrations.Identities.Queries.GetInternalEmployeeIdentities;

public sealed class GetInternalEmployeeIdentitiesQueryHandler(IEmployeeIdentityLookupRepository repository)
    : IRequestHandler<GetInternalEmployeeIdentitiesQuery, IReadOnlyList<InternalEmployeeIdentityDTO>>
{
    public Task<IReadOnlyList<InternalEmployeeIdentityDTO>> Handle(
        GetInternalEmployeeIdentitiesQuery query,
        CancellationToken cancellationToken) =>
        repository.GetCompanyIdentitiesAsync(query.CompanyId, cancellationToken);
}
