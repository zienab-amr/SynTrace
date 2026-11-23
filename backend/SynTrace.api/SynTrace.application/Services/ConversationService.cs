using System.Text.Json;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Application.Contracts.Repositories;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Exceptions;

namespace SynTrace.Application.Services;

/// <summary>Application-level read/delete use cases. AI orchestration lives in IAssistantConversationService.</summary>
public sealed class ConversationService(IConversationRepository repository, IUnitOfWork unitOfWork) : IConversationService
{
    public async Task<List<ConversationSummaryDTO>> GetConversationsAsync(CancellationToken ct)
    {
        var conversations = await repository.GetEmployeeConversationsAsync(ct);
        var previews = await repository.GetEmployeeConversationPreviewsAsync(ct);
        return conversations.Select(c => new ConversationSummaryDTO(c.Id, c.Title, c.CreatedAt,
            c.UpdatedAt, previews.GetValueOrDefault(c.Id))).ToList();
    }

    public async Task<List<ConversationMessageDTO>> GetMessagesAsync(string conversationId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(conversationId) ||
            await repository.GetConversationByIdAsync(conversationId, ct) is null)
            throw new RequestFailureException(404, "Conversation not found");

        var messages = await repository.GetConversationMessagesAsync(conversationId, ct);
        return messages.Select(m => new ConversationMessageDTO(m.ConversationMessageId, m.Question,
            m.Answer, m.Status, ParseLinks(m.LinksJson), m.CreatedAt, m.SequenceNumber)).ToList();
    }

    public async Task DeleteConversationAsync(string conversationId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(conversationId) ||
            !await repository.RemoveConversationAsync(conversationId, ct))
            throw new RequestFailureException(404, "Conversation not found");

        await unitOfWork.SaveChangesAsync(ct);
    }

    private static IReadOnlyList<AssistantLink> ParseLinks(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return [];
        try { return JsonSerializer.Deserialize<List<AssistantLink>>(json) ?? []; }
        catch (JsonException) { return []; }
    }
}
