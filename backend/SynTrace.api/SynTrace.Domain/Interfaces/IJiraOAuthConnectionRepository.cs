using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Entities;

namespace SynTrace.Domain.Interfaces
{
    public interface IJiraOAuthConnectionRepository
    {
        public Task<JiraOAuthState> CreateState(JiraOAuthState state);
        public Task<JiraOAuthState?> TryConsumeState(string stateHash);
        public Task CreateConnection(JiraConnection connection);
        public Task<bool> CheckConnection(string companyId);
        public Task<bool> CheckEmployeeConnection(string companyId, string employeeId);
        public Task<JiraConnection?> GetActiveCompanyConnection(string companyId);

    }
}
