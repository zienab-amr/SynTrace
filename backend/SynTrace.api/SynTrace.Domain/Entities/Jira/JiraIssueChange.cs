using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities.Jira
{
    public class JiraIssueChange
    {
        public string JiraIssueChangeId { get; set; }
        public string IssueKey { get; set; }
        public string Field { get; set; }
        public string? ChangesFrom { get; set; }
        public string? ChangesTo { get; set; }

        public string CompanyId { get; set; }

    }
}
