using MediatR;
using SynTrace.Application.Contracts.Knowledge;

namespace SynTrace.Application.Features.Knowledge.Queries.GetKnowledgeCompanies;

public sealed class GetKnowledgeCompaniesQueryHandler(IKnowledgeCompanyRepository repository)
    : IRequestHandler<GetKnowledgeCompaniesQuery, IReadOnlyList<string>>
{
    public Task<IReadOnlyList<string>> Handle(GetKnowledgeCompaniesQuery request, CancellationToken ct)
        => repository.GetCompaniesWithSourcesAsync(ct);
}
