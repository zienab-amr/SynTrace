using System.ComponentModel.DataAnnotations;
using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Queries.GetEmployeeById
{
    public class GetEmployeeByIdQuery : IRequest<SynTrace.Domain.Entities.Employee>
    {
        [Required, StringLength(100)]
        public string EmployeeId { get; set; } = string.Empty;
    }
}
