using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Employee.Commands.CreateEmployee;

public sealed class CreateEmployeeCommand : IRequest<Domain.Entities.Employee>
{
    [Required, StringLength(100)] public string FirstName { get; set; } = string.Empty;
    [Required, StringLength(100)] public string LastName { get; set; } = string.Empty;
    [Phone, StringLength(40)] public string? PhoneNumber { get; set; }
    [Required, EmailAddress, StringLength(256)] public string Email { get; set; } = string.Empty;
    [Required, StringLength(128, MinimumLength = 8)] public string Password { get; set; } = string.Empty;
    [StringLength(256)] public string? RoleId { get; set; }
    [StringLength(256)] public string? Role { get; set; }
}
