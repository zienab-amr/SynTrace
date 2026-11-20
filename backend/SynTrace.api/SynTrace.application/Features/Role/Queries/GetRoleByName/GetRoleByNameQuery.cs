using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;

namespace SynTrace.Application.Features.Role.Queries.GetRoleByName
{
    public class GetRoleByNameQuery : IRequest<SynTrace.Domain.Entities.Role?>
    {
        public string RoleName { set; get; }
    }
}
