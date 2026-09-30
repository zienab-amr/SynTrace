using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.Features.Role.Queries.GetAllRoles;

namespace SynTrace.Application.Features.Role.Queries.GetRoleByName
{
    internal class GetRoleByNameQueryHandler : IRequestHandler<GetRoleByNameQuery, IdentityRole>
    {
        private readonly IRoleService _roleService;
        private readonly RoleManager<IdentityRole> _roleManager;
        public GetRoleByNameQueryHandler(IRoleService roleService, RoleManager<IdentityRole> roleManager)
        {
            _roleService = roleService;
            _roleManager = roleManager;
        }

        public async Task<IdentityRole?> Handle(GetRoleByNameQuery request, CancellationToken cancellationToken)
        {
            var roleExisting = await _roleManager.RoleExistsAsync(request.RoleName);

            if (!roleExisting)
                throw new Exception("This Role not exist");

            return await _roleService.GetRoleByNameAsync(request.RoleName);
        }
    }
}
