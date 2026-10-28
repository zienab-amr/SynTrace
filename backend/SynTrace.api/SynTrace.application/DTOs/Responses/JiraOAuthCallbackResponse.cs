namespace SynTrace.Application.DTOs.Responses
{
    public sealed record JiraOAuthCallbackResponse(
        bool RequiresSiteSelection,
        string? PendingId,
        string Message
    );
}