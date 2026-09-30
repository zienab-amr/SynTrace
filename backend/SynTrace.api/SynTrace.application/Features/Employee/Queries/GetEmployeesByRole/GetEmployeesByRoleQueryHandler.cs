using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeesByRole
{
    public class GetEmployeesByRoleQueryHandler : IRequestHandler<GetEmployeesByRoleQuery, IList<SynTrace.Domain.Entities.Employee>>
    {
        private readonly IEmployeeRepository _repository;
        public GetEmployeesByRoleQueryHandler(IEmployeeRepository repository)
        {
            _repository = repository;
        }
        public async Task<IList<Domain.Entities.Employee>> Handle(GetEmployeesByRoleQuery request, CancellationToken cancellationToken)
        {
            var employees = await _repository.GetEmployeesByRoleAsync(request.Role);

            return employees;

        }
    }
}
