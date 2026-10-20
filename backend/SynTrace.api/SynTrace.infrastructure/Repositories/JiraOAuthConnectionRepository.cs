using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories
{
    public class JiraOAuthConnectionRepository : IJiraOAuthConnectionRepository
    {
        private readonly SynTraceDbContext _context;
        public JiraOAuthConnectionRepository(SynTraceDbContext context)
        {
            _context = context;
        }
        public async Task<JiraOAuthState> CreateState(JiraOAuthState state)
        {
            var status = await _context.JiraOAuthStates.AddAsync(state);

            var companyExists = await _context.Companies
                                .AnyAsync(c => c.CompanyId == state.CompanyId);

            Console.WriteLine($"CompanyId: {state.CompanyId}");
            Console.WriteLine($"Company exists: {companyExists}");
            Console.WriteLine($"Database: {_context.Database.GetDbConnection().Database}");
            await _context.SaveChangesAsync();

            return status.Entity;
        }

        public async Task<JiraOAuthState?> TryConsumeState(string stateHash)
        {
            var now = DateTime.UtcNow;

            var affectedRows = await _context.JiraOAuthStates
                .Where(x =>
                    x.StateHash == stateHash &&
                    x.ConsumedAt == null &&
                    x.ExpiresAt > now)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(x => x.ConsumedAt, now));

            if (affectedRows != 1)
                return null;

            return await _context.JiraOAuthStates
                .AsNoTracking()
                .SingleOrDefaultAsync(x => x.StateHash == stateHash);
        }

        public async Task CreateConnection(JiraConnection connection)
        {
            await _context.JiraConnections.AddAsync(connection);
            await _context.SaveChangesAsync();
        }
    }
}
