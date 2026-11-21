using System.ComponentModel.DataAnnotations;
using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeesByName
{
    public class GetEmployeesByNameQuery : IRequest<List<SynTrace.Domain.Entities.Employee>>
    {
        [Required, StringLength(100)]
        public string Name { get; set; } = string.Empty;
    }
}
