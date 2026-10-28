using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Integrations.Jira.Commands.ConnectEmployeeJira
{
    public record ConnectEmployeeJiraCommand : IRequest<string>;
}
