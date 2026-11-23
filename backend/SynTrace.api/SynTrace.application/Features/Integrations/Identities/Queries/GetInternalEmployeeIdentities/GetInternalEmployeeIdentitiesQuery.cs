using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Integrations.Identities.Queries.GetInternalEmployeeIdentities;

public sealed record GetInternalEmployeeIdentitiesQuery(string CompanyId)
    : IRequest<IReadOnlyList<InternalEmployeeIdentityDTO>>;
