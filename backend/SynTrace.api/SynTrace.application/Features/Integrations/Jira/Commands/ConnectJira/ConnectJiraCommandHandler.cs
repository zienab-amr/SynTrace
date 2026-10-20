using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts.Integrations.Jira;

namespace SynTrace.Application.Features.Integrations.Jira.Queries.ConnectJira
{
    public class ConnectJiraCommandHandler : IRequestHandler<ConnectJiraCommand, string>
    {
        private readonly IJiraOAuthService _jiraOAuthService;
        public ConnectJiraCommandHandler(IJiraOAuthService jiraOAuthService)
        {
            _jiraOAuthService = jiraOAuthService;
        }
        public async Task<string> Handle(ConnectJiraCommand request, CancellationToken cancellationToken)
        {
            return await _jiraOAuthService.ConnectJira();
        }
    }
}
