using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities.Jira;
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

        public Task ResetAiImportAsync(string connectionId) =>
            _context.JiraConnections.Where(c => c.Id == connectionId)
                .ExecuteUpdateAsync(u => u.SetProperty(c => c.AiImportCompletedAt, (DateTime?)null));

        public async Task<JiraConnection?> GetActiveCompanyConnection(string companyId)
        {
            return await _context.JiraConnections
                .AsNoTracking()
                .SingleOrDefaultAsync(c =>
                    c.CompanyId == companyId &&
                    c.JiraConnectionType == JiraConnectionType.Company &&
                    c.status);
        }

        public async Task UpdateConnectionTokensAsync(
        string connectionId,
        string encryptedAccessToken,
        string? encryptedRefreshToken)
        {
            var connection = await _context.JiraConnections
                .SingleOrDefaultAsync(c => c.Id == connectionId);

            if (connection is null)
            {
                throw new InvalidOperationException(
                    "Jira connection was not found.");
            }

            connection.EncryptedAccessToken = encryptedAccessToken;

            if (!string.IsNullOrWhiteSpace(encryptedRefreshToken))
            {
                connection.EncryptedRefreshToken = encryptedRefreshToken;
            }

            connection.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
        }
    }
}
