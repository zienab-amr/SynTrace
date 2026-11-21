using System.ComponentModel.DataAnnotations;
using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Commands.DeleteEmployee
{
    public class DeleteEmployeeCommand : IRequest<bool>
    {
        [Required, StringLength(100)]
        public string EmployeeId { get; set; } = string.Empty;
    }
}
