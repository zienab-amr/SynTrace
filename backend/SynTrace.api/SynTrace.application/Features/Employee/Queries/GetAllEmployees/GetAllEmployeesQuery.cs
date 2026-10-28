using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Queries.GetAllEmployees
{
    public class GetAllEmployeesQuery : IRequest<List<SynTrace.Domain.Entities.Employee>>;

}
