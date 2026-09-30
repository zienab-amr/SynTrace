using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeesByName
{
    public class GetEmployeesByNameQuery : IRequest<List<SynTrace.Domain.Entities.Employee>>
    {
        public string Name { get; set; }
    }
}
