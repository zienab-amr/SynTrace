using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Entities;

namespace SynTrace.Application.Features.Employee.Commands.CreateEmployee
{
    public class CreateEmployeeCommand : IRequest<SynTrace.Domain.Entities.Employee>
    {
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string PhoneNumber { get; set; }
        public string Email { get; set; }
        public string Password { get; set; }
        public string Role { get; set; }
    }
}
