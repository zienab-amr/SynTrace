using MediatR;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Commands.UpdateRole;

public sealed class UpdateRoleCommandHandler(IRoleService roles) : IRequestHandler<UpdateRoleCommand>
{
    public Task Handle(UpdateRoleCommand request, CancellationToken cancellationToken) =>
        roles.UpdateRoleAsync(request.RoleId, request.OldRoleName, request.NewRoleName);
}
