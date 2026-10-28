using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts.Integrations.Jira;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Integrations.Jira.Commands.CallBack
{
    public class CallBackCommandHandler : IRequestHandler<CallBackCommand, JiraOAuthCallbackResponse>
    {
        private readonly IJiraOAuthService _jiraOAuthService;

        public CallBackCommandHandler(IJiraOAuthService jiraOAuthService)
        {
            _jiraOAuthService = jiraOAuthService;
        }

        public Task<JiraOAuthCallbackResponse> Handle(
            CallBackCommand request,
            CancellationToken cancellationToken)
        {
            return _jiraOAuthService.CallBack(
                request.Code,
                request.State,
                cancellationToken);
        }
    }
}
