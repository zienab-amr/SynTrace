using MediatR;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Assistant.Commands.AskAssistant;

public sealed class AskAssistantCommandHandler(IAssistantConversationService assistant)
    : IRequestHandler<AskAssistantCommand, AssistantAskResponseDTO>
{
    public Task<AssistantAskResponseDTO> Handle(AskAssistantCommand request, CancellationToken ct)
        => assistant.AskAsync(request.Question ?? "", request.ConversationId, request.EditedMessageId,
            request.AppendToMessageId, request.ClientMessageId, request.QuotedExcerpts, ct,
            request.Transcript, request.MeetingDate);
}
