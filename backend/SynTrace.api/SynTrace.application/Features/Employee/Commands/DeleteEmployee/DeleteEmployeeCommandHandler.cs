using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Commands.DeleteEmployee
{
    public class DeleteEmployeeCommandHandler : IRequestHandler<DeleteEmployeeCommand, bool>
    {
        private readonly IEmployeeRepository _repository;
        public DeleteEmployeeCommandHandler(IEmployeeRepository repository)
        {
            _repository = repository;
        }
        public  async Task<bool> Handle(DeleteEmployeeCommand request, CancellationToken cancellationToken)
        {
            var employee = await _repository.GetEmployeeByIdAsync(request.EmployeeId);

            if(employee == null)
                throw new Exception("Sorry, Employee not found");

            var result = await _repository.DeleteEmployeeAsync(employee);


            if (!result.Succeeded)
            {
                throw new InvalidOperationException(
                    string.Join(", ", result.Errors.Select(e => e.Description))
                );
            }

            return true;

        }
    }
}
