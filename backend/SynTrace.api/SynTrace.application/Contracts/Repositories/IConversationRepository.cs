using SynTrace.Domain.Entities;

namespace SynTrace.Application.Contracts.Repositories;

public interface IConversationRepository
{
    Task AddConversationAsync(Conversation conversation, CancellationToken ct);
    // Tracked entity: RowVersion is checked on updates after the AI call.
    Task<Conversation?> GetConversationByIdAsync(string conversationId, CancellationToken ct);
    Task<Dictionary<string, string?>> GetEmployeeConversationPreviewsAsync(CancellationToken ct);
    Task<List<Conversation>> GetEmployeeConversationsAsync(CancellationToken ct);
    Task<ConversationMessage?> GetMessageByClientMessageIdAsync(string clientMessageId, CancellationToken ct);
    Task<List<ConversationMessage>> GetConversationMessagesAsync(string conversationId, CancellationToken ct);
    Task<List<ConversationMessage>> GetLastMessagesAsync(string conversationId, int count, CancellationToken ct);
    Task<List<ConversationMessage>> GetLastMessagesBeforeSequenceAsync(string conversationId, long beforeSequence, int count, CancellationToken ct);
    Task<ConversationMessage?> GetMessageByIdAsync(string conversationId, string messageId, CancellationToken ct);
    Task<List<ConversationMessage>> GetMessagesFromSequenceAsync(string conversationId, long sequenceNumber, CancellationToken ct);
    Task AddMessageAsync(ConversationMessage message, CancellationToken ct);
    void RemoveMessages(IEnumerable<ConversationMessage> messages);
    Task<bool> RemoveConversationAsync(string conversationId, CancellationToken ct);
}
