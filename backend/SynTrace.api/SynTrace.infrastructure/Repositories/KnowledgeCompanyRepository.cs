using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts.Knowledge;
using SynTrace.Domain.Entities.Knowledge;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories;

public sealed class KnowledgeCompanyRepository(SynTraceDbContext db) : IKnowledgeCompanyRepository
{
    public async Task<IReadOnlyList<string>> GetCompaniesWithSourcesAsync(CancellationToken ct)
        => await db.Set<KnowledgeSource>().AsNoTracking()
            .Where(s => !s.Withdrawn)
            .Select(s => s.CompanyId).Distinct().OrderBy(id => id)
            .ToListAsync(ct);
}
