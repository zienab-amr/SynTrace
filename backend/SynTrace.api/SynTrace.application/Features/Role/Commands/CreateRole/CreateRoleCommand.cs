using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Role.Commands.CreateRole;

public sealed class CreateRoleCommand : IRequest
{
    [Required, StringLength(256)] public string Role { get; set; } = string.Empty;
}
