using MediatR;
using SynTrace.Application.Contracts.Integrations.Jira;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Integrations.Jira.Queries.GetPendingCompanyJiraSites;

public sealed class GetPendingCompanyJiraSitesQueryHandler
    : IRequestHandler<GetPendingCompanyJiraSitesQuery,
        IReadOnlyList<JiraSiteOptionResponse>>
{
    private readonly IJiraOAuthService _service;

    public GetPendingCompanyJiraSitesQueryHandler(IJiraOAuthService service)
    {
        _service = service;
    }

    public Task<IReadOnlyList<JiraSiteOptionResponse>> Handle(
        GetPendingCompanyJiraSitesQuery request,
        CancellationToken cancellationToken)
    {
        return _service.GetPendingCompanyJiraSites(request.PendingId);
    }
}