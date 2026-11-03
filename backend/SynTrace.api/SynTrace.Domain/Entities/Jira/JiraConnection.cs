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

        /// <summary>Encrypted, not hashed: checking the HMAC signature needs the secret itself.</summary>
        public string? EncryptedAdminWebhookSecret { get; set; }
        public DateTime? AdminWebhookLastReceivedAt { get; set; }

        /// <summary>Null until the full copy of the issues has been sent to the AI.</summary>
        public DateTime? AiImportCompletedAt { get; set; }
    }
}
