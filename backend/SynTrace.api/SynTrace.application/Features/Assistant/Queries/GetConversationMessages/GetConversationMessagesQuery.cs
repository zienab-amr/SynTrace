using MediatR;
using SynTrace.Application.DTOs.Responses;
namespace SynTrace.Application.Features.Assistant.Queries.GetConversationMessages;
public sealed record GetConversationMessagesQuery(string ConversationId) : IRequest<List<ConversationMessageDTO>>;
