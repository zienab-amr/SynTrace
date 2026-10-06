using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeesByName
{
    public class GetEmployeesByNameQueryHandler : IRequestHandler<GetEmployeesByNameQuery, List<SynTrace.Domain.Entities.Employee>>
    {
        private readonly IEmployeeRepository _repository;
        public GetEmployeesByNameQueryHandler(IEmployeeRepository repository)
        {
            _repository = repository;
        }
        public async Task<List<Domain.Entities.Employee>> Handle(GetEmployeesByNameQuery request, CancellationToken cancellationToken)
        {
            var result = await _repository.GetEmployeesByNameAsync(request.Name);

            if (result == null)
                throw new Exception("Result is Empty");

            return result;
        }
    }
}
