using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Queries.GetAllRoles
{
    public class GetAllRolesQueryHandler : IRequestHandler<GetAllRolesQuery, List<IdentityRole>>
    {
        private readonly IRoleService _roleService;
        public GetAllRolesQueryHandler(IRoleService roleService, RoleManager<IdentityRole> roleManager)
        {
            _roleService = roleService;
        }
        public async Task<List<IdentityRole>> Handle(GetAllRolesQuery request, CancellationToken cancellationToken)
        {
            return await _roleService.GetAllRolesAsync();
        }
    }
}
