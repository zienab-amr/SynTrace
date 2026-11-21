using SynTrace.Application.Exceptions;
using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Commands.UpdateEmployee
{
    public class UpdateEmployeeCommandHandler : IRequestHandler<UpdateEmployeeCommand, SynTrace.Domain.Entities.Employee>
    {
        private readonly IEmployeeRepository _repository;
        public UpdateEmployeeCommandHandler(IEmployeeRepository repository)
        {
            _repository = repository;
        }
        public async Task<Domain.Entities.Employee> Handle(UpdateEmployeeCommand request, CancellationToken cancellationToken)
        {
            var employee = await _repository.GetEmployeeByIdAsync(request.EmployeeId);

            if (employee == null)
            {
                throw new RequestFailureException(404, "Employee was not found.");
            }

            if (request.Email is not null && !string.Equals(employee.Email, request.Email.Trim(), StringComparison.OrdinalIgnoreCase))
                throw new RequestFailureException(400, "Changing an account email requires separate verification.");

            employee.FirstName = request.FirstName.Trim();
            employee.LastName = request.LastName.Trim();
            employee.PhoneNumber = request.PhoneNumber;

            var result = await _repository.UpdateEmployeeAsync(employee);

            if (!result.Succeeded)
            {
                throw new RequestFailureException(409,
                    string.Join(", ", result.Errors.Select(e => e.Description)));
            }

            return employee;


        }
    }
}
