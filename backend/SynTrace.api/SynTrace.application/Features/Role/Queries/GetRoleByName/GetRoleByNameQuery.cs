using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Role.Queries.GetRoleByName;

public sealed class GetRoleByNameQuery : IRequest<Domain.Entities.Role?>
{
    [Required, StringLength(256)] public string RoleName { get; set; } = string.Empty;
}
