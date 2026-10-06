using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeeById
{
    public class GetEmployeeByIdQueryHandler : IRequestHandler<GetEmployeeByIdQuery, SynTrace.Domain.Entities.Employee>
    {
        private readonly IEmployeeRepository _repository;
        public GetEmployeeByIdQueryHandler(IEmployeeRepository repository)
        {
            _repository = repository;
        }
        public async Task<Domain.Entities.Employee> Handle(GetEmployeeByIdQuery request, CancellationToken cancellationToken)
        {
            var employee = await _repository.GetEmployeeByIdAsync(request.EmployeeId);
            if (employee == null)
                throw new Exception("Employee not found");

            return employee;

        }
    }
}
