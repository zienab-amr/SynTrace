using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Commands.DeleteRole
{
    public class DeleteRoleCommandHandler : IRequestHandler<DeleteRoleCommand>
    {
        private readonly IRoleService _roleService;

        public DeleteRoleCommandHandler(IRoleService roleService)
        {
            _roleService = roleService;
        }

        public async Task Handle(
            DeleteRoleCommand request,
            CancellationToken cancellationToken)
        {
            var role = await _roleService.GetRoleByNameAsync(request.Role);

            if (role == null)
                throw new Exception("This role does not exist");

            var result = await _roleService.DeleteRoleAsync(request.Role);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description))
                );
            }
        }
    }
}
