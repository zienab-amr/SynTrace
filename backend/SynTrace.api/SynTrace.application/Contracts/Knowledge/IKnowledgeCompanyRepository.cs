namespace SynTrace.Application.Contracts.Knowledge;

public interface IKnowledgeCompanyRepository
{
    Task<IReadOnlyList<string>> GetCompaniesWithSourcesAsync(CancellationToken cancellationToken);
}
