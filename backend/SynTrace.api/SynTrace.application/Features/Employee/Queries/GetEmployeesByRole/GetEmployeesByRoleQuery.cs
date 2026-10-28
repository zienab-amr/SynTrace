using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeesByRole
{
    public class GetEmployeesByRoleQuery : IRequest<IList<SynTrace.Domain.Entities.Employee>>
    {
        public string Role { get; set; }
    }
}
