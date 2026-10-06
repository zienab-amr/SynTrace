using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Role.Commands.UpdateRole
{
    public class UpdateRoleCommand : IRequest
    {
        public string OldRoleName { set; get; }
        public string NewRoleName { set; get; }

    }
}
