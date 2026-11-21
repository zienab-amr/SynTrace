using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Role.Commands.DeleteRole;

public sealed class DeleteRoleCommand : IRequest
{
    [StringLength(256)] public string? RoleId { get; set; }
    [StringLength(256)] public string? Role { get; set; }
}
