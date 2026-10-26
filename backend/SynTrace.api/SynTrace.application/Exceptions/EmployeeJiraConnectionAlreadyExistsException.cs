using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.Exceptions
{
    public class EmployeeJiraConnectionAlreadyExistsException : Exception
    {
        public EmployeeJiraConnectionAlreadyExistsException(string message) : base(message) { }
    }
}
