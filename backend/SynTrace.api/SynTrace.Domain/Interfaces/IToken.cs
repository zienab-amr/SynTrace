using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Entities;

namespace SynTrace.Domain.Interfaces
{
    public interface IToken
    {
        public Task<string> GenerateToken(Employee request);
    }
}
