using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.Features.Role.Queries.GetAllRoles;

namespace SynTrace.Application.Features.Role.Queries.GetRoleByName
{
    public class GetRoleByNameQueryHandler : IRequestHandler<GetRoleByNameQuery, SynTrace.Domain.Entities.Role?>
    {
        private readonly IRoleService _roleService;
        public GetRoleByNameQueryHandler(IRoleService roleService)
        {
            _roleService = roleService;
        }

        public async Task<SynTrace.Domain.Entities.Role?> Handle(GetRoleByNameQuery request, CancellationToken cancellationToken)
        {
            var role = await _roleService.GetRoleByNameAsync(request.RoleName);

            if (role == null)
                throw new Exception("This Role does not exist.");

            return role;
        }
    }
}
