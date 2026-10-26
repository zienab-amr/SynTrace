using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Integrations.Jira.Queries.GetPendingCompanyJiraSites;

public sealed record GetPendingCompanyJiraSitesQuery(string PendingId)
    : IRequest<IReadOnlyList<JiraSiteOptionResponse>>;