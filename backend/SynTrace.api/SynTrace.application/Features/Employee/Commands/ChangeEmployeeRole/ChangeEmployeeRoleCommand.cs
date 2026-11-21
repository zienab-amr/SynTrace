using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Employee.Commands.ChangeEmployee;

public sealed class ChangeEmployeeRoleCommand : IRequest
{
    [Required, StringLength(100)] public string EmployeeId { get; set; } = string.Empty;
    [StringLength(256)] public string? NewRoleId { get; set; }
    [StringLength(256)] public string? PreviousRoleId { get; set; }
    [StringLength(256)] public string? NewRole { get; set; }
}
