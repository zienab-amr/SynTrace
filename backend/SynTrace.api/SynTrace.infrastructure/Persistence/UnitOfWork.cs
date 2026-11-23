using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using SynTrace.Application.Contracts;
using SynTrace.Application.Exceptions;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Persistence;

public sealed class UnitOfWork(SynTraceDbContext db) : IUnitOfWork
{
    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        try { return await db.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateConcurrencyException ex)
        {
            throw new ConversationConcurrencyException("Optimistic concurrency conflict.", ex);
        }
        catch (DbUpdateException ex) when (ex.InnerException is SqlException sql && sql.Number is 2601 or 2627)
        {
            throw new ConversationConcurrencyException("Unique constraint conflict.", ex);
        }
    }
}
