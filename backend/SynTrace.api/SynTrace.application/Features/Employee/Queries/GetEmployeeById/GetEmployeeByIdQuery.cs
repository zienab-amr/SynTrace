using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeeById
{
    public class GetEmployeeByIdQuery : IRequest<SynTrace.Domain.Entities.Employee>
    {
        public string EmployeeId { get; set; }
    }
}
