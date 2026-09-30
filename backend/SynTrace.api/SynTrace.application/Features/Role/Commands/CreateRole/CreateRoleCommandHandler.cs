using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using Microsoft.AspNetCore.Identity;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Commands.CreateRole
{
    public class CreateRoleCommandHandler : IRequestHandler<CreateRoleCommand>
    {
        private readonly IRoleService _roleService;

        public CreateRoleCommandHandler(IRoleService roleService)
        {
            _roleService = roleService;
        }

        public async Task Handle(
            CreateRoleCommand request,
            CancellationToken cancellationToken)
        {
            var existingRole = await _roleService
                .GetRoleByNameAsync(request.Role);

            if (existingRole != null)
                throw new Exception("This role already exists");

            var result = await _roleService
                .CreateRoleAsync(request.Role);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description))
                );
            }
        }
    }
}
