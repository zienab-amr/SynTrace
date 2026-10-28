using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Integrations.Jira.Queries.ConnectJira
{
    public record ConnectCompanyJiraCommand : IRequest<string>;
}
