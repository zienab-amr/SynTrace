using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Contracts.Integrations.Jira
{
    public interface IJiraOAuthService
    {
        public Task<string> ConnectJira();
        public Task<JiraOAuthCallbackResponse> CallBack(
            string code,
            string state,
            CancellationToken cancellationToken
        );

        public Task<IReadOnlyList<JiraSiteOptionResponse>> GetPendingCompanyJiraSites(
            string pendingId
        );

        public Task CompleteCompanyJiraConnection(
            string pendingId,
            string cloudId,
            CancellationToken cancellationToken
        ); public Task<string> ConnectEmployeeJira();
    }
}
