using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Contracts;

public interface IConversationService
{
    Task<List<ConversationSummaryDTO>> GetConversationsAsync(CancellationToken cancellationToken);
    Task<List<ConversationMessageDTO>> GetMessagesAsync(string conversationId, CancellationToken cancellationToken);
    Task DeleteConversationAsync(string conversationId, CancellationToken cancellationToken);
}
