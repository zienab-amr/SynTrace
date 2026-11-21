using MediatR;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Role.Commands.DeleteRole;

public sealed class DeleteRoleCommandHandler(IRoleService roles) : IRequestHandler<DeleteRoleCommand>
{
    public Task Handle(DeleteRoleCommand request, CancellationToken cancellationToken) =>
        roles.DeleteRoleAsync(request.RoleId, request.Role);
}
