using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities.Jira
{
    public sealed class JiraIssueProjection
    {
        public string JiraIssueProjectionId { get; set; } = Guid.NewGuid().ToString();

        public string CompanyId { get; set; } = string.Empty;
        public string JiraConnectionId { get; set; } = string.Empty;

        public string JiraIssueId { get; set; } = string.Empty;
        public string IssueKey { get; set; } = string.Empty;

        public string? ProjectId { get; set; }
        public string? ProjectKey { get; set; }

        public string? Summary { get; set; }
        public string? Status { get; set; }
        public string? AssigneeAccountId { get; set; }

        public DateTimeOffset? SourceUpdatedAtUtc { get; set; }
        public DateTimeOffset LastSyncedAtUtc { get; set; }
    }
}
