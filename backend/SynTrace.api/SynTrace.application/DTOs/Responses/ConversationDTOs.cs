using SynTrace.Application.Contracts.Assistant;

namespace SynTrace.Application.DTOs.Responses;

public sealed record ConversationSummaryDTO(
    string Id, string Title, DateTime CreatedAt, DateTime UpdatedAt, string? Preview = null);

public sealed record ConversationMessageDTO(
    string Id, string Question, string Answer, string Status,
    IReadOnlyList<AssistantLink> Links, DateTime CreatedAt, long SequenceNumber);

public sealed record AssistantAskResponseDTO(
    string ConversationId, string MessageId, string Status, string Answer,
    IReadOnlyList<AssistantLink> Links, string CorrelationId);
