namespace SynTrace.Infrastructure.Options;

public sealed class AiServiceOptions
{
    public const string SectionName = "AiService";

    public string BaseUrl { get; set; } = string.Empty;
    public string ApiKey { get; set; } = string.Empty;
    public bool EnableSynTraceProjectScope { get; set; }
    // Enable only after the AI service implements the new permissions/scope contract.
    public bool EnableMeetingContract { get; set; }
    public int MeetingHistoryCount { get; set; } = 20;
    public int TimeoutSeconds { get; set; } = 90;
}
