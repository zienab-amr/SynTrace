using System;
using System.Collections.Generic;
using System.Text;
using MediatR;

namespace SynTrace.Application.Features.Employee.Commands.ChangeEmployee
{
    public class ChangeEmployeeRoleCommand : IRequest
    {
        public string EmployeeId { get; set; }
        public string NewRole { get; set; }
    }
}
