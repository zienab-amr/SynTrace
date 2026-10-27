using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads
{
    public class JiraIssuePayload
    {
        public string IssueId { get; init; } = string.Empty;

        public string IssueKey { get; init; } = string.Empty;

        public string? ProjectId { get; init; }

        public string? ProjectKey { get; init; }

        public string? Summary { get; init; }
    }
}
