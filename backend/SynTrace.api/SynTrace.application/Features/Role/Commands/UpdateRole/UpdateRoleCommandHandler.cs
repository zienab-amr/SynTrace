using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Commands.UpdateRole
{
    public class UpdateRoleCommandHandler : IRequestHandler<UpdateRoleCommand>
    {
        private readonly IRoleService _roleService;
        private readonly RoleManager<IdentityRole> _roleManager;
        public UpdateRoleCommandHandler(IRoleService roleService, RoleManager<IdentityRole> roleManager)
        {
            _roleService = roleService;
            _roleManager = roleManager;
        }
        public async Task Handle(UpdateRoleCommand request, CancellationToken cancellationToken)
        {
            var role = await _roleService.GetRoleByNameAsync(request.OldRoleName);

            if (role == null)
                throw new Exception("This role does not exist");

            var result = await _roleService.UpdateRoleAsync(request.OldRoleName, request.NewRoleName);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description))
                );
            }
        }
    }
}
