using SynTrace.Domain.Enums;
using SynTrace.Domain.Enums.Jira;

namespace SynTrace.Domain.Entities.Jira
{
    public class JiraConnection
    {
        public string Id { get; set; } = string.Empty;
        public string JiraAccountId { get; set; } = string.Empty;
        public string CloudId { get; set; } = string.Empty;
        public string SiteUrl { get; set; } = string.Empty;
        public string EncryptedAccessToken { get; set; } = string.Empty;
        public string? EncryptedRefreshToken { get; set; }
        public string ConnectedByEmployeeId { get; set; } = string.Empty;
        public JiraConnectionType JiraConnectionType { get; set; }
        public Employee ConnectedByEmployee { get; set; } = null!;
        public string CompanyId { get; set; } = string.Empty;
        public Company Company { get; set; } = null!;
        public bool status { get; set; } = true;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        public long? WebhookId { get; set; }
        public string? WebhookSecretHash { get; set; }
        public DateTime? WebhookExpiresAt { get; set; }

        public JiraSyncStatus SyncStatus { get; set; } = JiraSyncStatus.NotStarted;
        public DateTime? LastSyncedAt { get; set; }
        public string? LastSyncError { get; set; }
    }
}
