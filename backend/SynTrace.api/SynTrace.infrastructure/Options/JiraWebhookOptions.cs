namespace SynTrace.Infrastructure.Options;

public sealed class JiraWebhookOptions
{
    public const string SectionName = "JiraWebhook";
    public int MaxBodyBytes { get; set; } = 1_048_576;
    public int MaxEventAgeMinutes { get; set; } = 1440;
    public string? HmacSecret { get; set; }
    public bool RequireHmac { get; set; }
}
