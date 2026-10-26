using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts.Integrations.Jira;

namespace SynTrace.Application.Features.Integrations.Jira.Commands.ConnectEmployeeJira
{
    public class ConnectEmployeeJiraCommandHandler : IRequestHandler<ConnectEmployeeJiraCommand, string>
    {
        private readonly IJiraOAuthService _jiraOAuthService;
        public ConnectEmployeeJiraCommandHandler(IJiraOAuthService jiraOAuthService)
        {
            _jiraOAuthService = jiraOAuthService;
        }
        public async Task<string> Handle(ConnectEmployeeJiraCommand request, CancellationToken cancellationToken)
        {
            return await _jiraOAuthService.ConnectEmployeeJira();
        }
    }
}
