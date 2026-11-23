namespace SynTrace.Infrastructure.Options;

public sealed class AiServiceOptions
{
    public const string SectionName = "AiService";

    public string BaseUrl { get; set; } = string.Empty;
    public string ApiKey { get; set; } = string.Empty;
    public bool EnableSynTraceProjectScope { get; set; }
    public int TimeoutSeconds { get; set; } = 90;
}
