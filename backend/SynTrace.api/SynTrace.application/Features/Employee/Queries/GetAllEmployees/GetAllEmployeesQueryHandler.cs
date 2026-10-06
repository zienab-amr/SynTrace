using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Queries.GetAllEmployees
{
    public class GetAllEmployeesQueryHandler : IRequestHandler<GetAllEmployeesQuery, List<SynTrace.Domain.Entities.Employee>>
    {
        private readonly IEmployeeRepository _repository;
        public GetAllEmployeesQueryHandler(IEmployeeRepository repository)
        {
            _repository = repository;
        }
        public async Task<List<SynTrace.Domain.Entities.Employee>> Handle(GetAllEmployeesQuery request, CancellationToken cancellationToken)
        {
            return await _repository.GetAllEmployeesAsync();
        }
    }
}
