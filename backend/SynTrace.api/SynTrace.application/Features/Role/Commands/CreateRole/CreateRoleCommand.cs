using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Commands.CreateRole
{
    public class CreateRoleCommand : IRequest
    {
        public string Role { get; set; }
    }

}
