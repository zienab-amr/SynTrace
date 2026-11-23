using MediatR;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Responses;
namespace SynTrace.Application.Features.Assistant.Queries.GetConversationMessages;
public sealed class GetConversationMessagesQueryHandler(IConversationService service)
    : IRequestHandler<GetConversationMessagesQuery, List<ConversationMessageDTO>>
{
    public Task<List<ConversationMessageDTO>> Handle(GetConversationMessagesQuery request, CancellationToken ct)
        => service.GetMessagesAsync(request.ConversationId, ct);
}
