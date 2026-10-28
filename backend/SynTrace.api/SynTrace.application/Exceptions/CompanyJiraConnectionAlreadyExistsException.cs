using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Application.Exceptions
{
    public class CompanyJiraConnectionAlreadyExistsException : Exception
    {
        public CompanyJiraConnectionAlreadyExistsException(string message) : base(message) { }

    }
}
