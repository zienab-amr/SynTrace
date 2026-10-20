using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Integrations.Jira.Commands.CallBack
{
    public class CallBackCommand : IRequest<Unit>
    {
        public string Code { get; set; }
        public string State { get; set; }
    }
}
