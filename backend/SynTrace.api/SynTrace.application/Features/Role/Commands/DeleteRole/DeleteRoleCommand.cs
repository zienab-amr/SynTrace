using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Role.Commands.DeleteRole
{
    public class DeleteRoleCommand : IRequest
    {
        public string Role { get; set; }
    }
}
