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
        public UpdateRoleCommandHandler(IRoleService roleService)
        {
            _roleService = roleService;
        }
        public async Task Handle(UpdateRoleCommand request, CancellationToken cancellationToken)
        {
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
