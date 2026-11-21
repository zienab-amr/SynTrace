using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Role.Commands.UpdateRole;

public sealed class UpdateRoleCommand : IRequest
{
    [StringLength(256)] public string? RoleId { get; set; }
    [StringLength(256)] public string? OldRoleName { get; set; }
    [Required, StringLength(256)] public string NewRoleName { get; set; } = string.Empty;
}
