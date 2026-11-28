using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Assistant.Commands.AskAssistant;

// clientMessageId is a Flutter-generated GUID for the FIRST unanswered bubble.
// appendToMessageId refers to that same temporary ID, not a persisted DB message ID.
public sealed record AskAssistantCommand(
    string? Question,
    string? ConversationId = null,
    string? EditedMessageId = null,
    string? AppendToMessageId = null,
    string? ClientMessageId = null,
    IReadOnlyList<string>? QuotedExcerpts = null,
    // A part of a meeting transcript pasted in the chat during the meeting (live help).
    string? Transcript = null,
    string? MeetingDate = null) : IRequest<AssistantAskResponseDTO>;
