using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Queries.GetAllRoles
{
    public class GetAllRolesQueryHandler : IRequestHandler<GetAllRolesQuery, List<SynTrace.Domain.Entities.Role>>
    {
        private readonly IRoleService _roleService;
        public GetAllRolesQueryHandler(IRoleService roleService)
        {
            _roleService = roleService;
        }
        public async Task<List<SynTrace.Domain.Entities.Role>> Handle(GetAllRolesQuery request, CancellationToken cancellationToken)
        {
            return await _roleService.GetAllRolesAsync();
        }
    }
}
