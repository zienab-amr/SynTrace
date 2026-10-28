using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Enums;
using SynTrace.Domain.Interfaces;
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

        public async Task<bool> CheckConnection(string companyId)
        {
            var check = await _context.JiraConnections.AnyAsync(c => c.status && c.CompanyId == companyId && c.JiraConnectionType == Domain.Enums.JiraConnectionType.Company);
            return check;   
        }

        public async Task<bool> CheckEmployeeConnection(string companyId, string employeeId)
        {
            var check = await _context.JiraConnections.AnyAsync(c => c.status 
                                && c.CompanyId == companyId 
                                && c.JiraConnectionType == Domain.Enums.JiraConnectionType.Employee 
                                && c.ConnectedByEmployeeId == employeeId);
            return check;
        }

        public async Task<JiraConnection?> GetActiveCompanyConnection(string companyId)
        {
            return await _context.JiraConnections
                .AsNoTracking()
                .SingleOrDefaultAsync(c =>
                    c.CompanyId == companyId &&
                    c.JiraConnectionType == JiraConnectionType.Company &&
                    c.status);
        }
    }
}
