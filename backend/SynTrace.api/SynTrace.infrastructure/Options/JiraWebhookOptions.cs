namespace SynTrace.Infrastructure.Options;

public sealed class JiraWebhookOptions
{
    public const string SectionName = "JiraWebhook";
    public int MaxBodyBytes { get; set; } = 26 * 1024 * 1024;   // Jira sends webhooks up to 25 MB
    public int MaxEventAgeMinutes { get; set; } = 1440;
    public string? HmacSecret { get; set; }
    public bool RequireHmac { get; set; }

    /// <summary>A bearer token is always checked when present. True also rejects requests without one.</summary>
    public bool RequireOAuthJwt { get; set; }
}
