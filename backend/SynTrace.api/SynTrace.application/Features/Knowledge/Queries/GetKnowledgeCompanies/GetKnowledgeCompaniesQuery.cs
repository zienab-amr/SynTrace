using MediatR;

namespace SynTrace.Application.Features.Knowledge.Queries.GetKnowledgeCompanies;

public sealed record GetKnowledgeCompaniesQuery() : IRequest<IReadOnlyList<string>>;
