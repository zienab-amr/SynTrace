using MediatR;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Responses;
namespace SynTrace.Application.Features.Assistant.Queries.GetConversations;
public sealed class GetConversationsQueryHandler(IConversationService service)
    : IRequestHandler<GetConversationsQuery, List<ConversationSummaryDTO>>
{
    public Task<List<ConversationSummaryDTO>> Handle(GetConversationsQuery request, CancellationToken ct)
        => service.GetConversationsAsync(ct);
}
