using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Enums.Jira
{
    public enum JiraSyncStatus
    {
        NotStarted = 0,
        Running = 1,
        Completed = 2,
        Failed = 3
    }
}
