using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Contracts.Integrations.Jira
{
    public interface IJiraOAuthService
    {
        public Task<string> ConnectJira();
        public Task CallBack(string code, string state, CancellationToken cancellationToken);



    }
}
