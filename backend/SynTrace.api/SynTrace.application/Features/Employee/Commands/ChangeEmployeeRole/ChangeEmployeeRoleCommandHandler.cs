using MediatR;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Commands.ChangeEmployee;

public sealed class ChangeEmployeeRoleCommandHandler(IEmployeeRepository repository)
    : IRequestHandler<ChangeEmployeeRoleCommand>
{
    public async Task Handle(ChangeEmployeeRoleCommand request, CancellationToken cancellationToken)
    {
        var role = request.NewRoleId ?? request.NewRole;
        if (string.IsNullOrWhiteSpace(role))
            throw new RequestFailureException(400, "NewRoleId is required.");

        var employee = await repository.GetEmployeeByIdAsync(request.EmployeeId)
            ?? throw new RequestFailureException(404, "Employee was not found.");

        await repository.ChangeEmployeeRole(employee, role, request.PreviousRoleId);
    }
}
