using MediatR;
using SynTrace.Application.Contracts;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Commands.CreateEmployee;

public sealed class CreateEmployeeCommandHandler(IEmployeeRepository repository, ICurrentTenant tenant)
    : IRequestHandler<CreateEmployeeCommand, Domain.Entities.Employee>
{
    public async Task<Domain.Entities.Employee> Handle(CreateEmployeeCommand request, CancellationToken cancellationToken)
    {
        var roleId = request.RoleId ?? request.Role;
        if (string.IsNullOrWhiteSpace(roleId))
            throw new RequestFailureException(400, "RoleId is required.");

        var employee = new Domain.Entities.Employee
        {
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            Email = request.Email.Trim(),
            UserName = request.Email.Trim(),
            PhoneNumber = request.PhoneNumber,
            CompanyId = tenant.CompanyId,
            LockoutEnabled = true
        };
        var result = await repository.CreateEmployeeAsync(employee, request.Password, roleId);
        if (!result.Succeeded)
            throw new RequestFailureException(400, string.Join(" ", result.Errors.Select(e => e.Description)));

        return employee;
    }
}
