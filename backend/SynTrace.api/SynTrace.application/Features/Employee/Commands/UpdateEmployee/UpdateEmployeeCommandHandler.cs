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
                throw new Exception("Sorry, not found this Employee");
            }

            employee.FirstName = request.FirstName;
            employee.LastName = request.LastName;
            employee.PhoneNumber = request.PhoneNumber;

            var result = await _repository.UpdateEmployeeAsync(employee);

            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description)));
            }

            return employee;


        }
    }
}
