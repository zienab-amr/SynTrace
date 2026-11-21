using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Employee.Commands.UpdateEmployee;

public sealed class UpdateEmployeeCommand : IRequest<Domain.Entities.Employee>
{
    [Required, StringLength(100)] public string EmployeeId { get; set; } = string.Empty;
    [Required, StringLength(100)] public string FirstName { get; set; } = string.Empty;
    [Required, StringLength(100)] public string LastName { get; set; } = string.Empty;
    [Phone, StringLength(40)] public string? PhoneNumber { get; set; }
    [EmailAddress, StringLength(256)] public string? Email { get; set; }
}
