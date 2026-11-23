using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Contracts.Assistant;

public interface IAssistantConversationService
{
    Task<AssistantAskResponseDTO> AskAsync(
        string question, string? conversationId, string? editedMessageId,
        string? appendToMessageId, string? clientMessageId,
        IReadOnlyList<string>? quotedExcerpts, CancellationToken cancellationToken);
}
