using MediatR;
using SynTrace.Application.DTOs.Responses;
namespace SynTrace.Application.Features.Assistant.Queries.GetConversations;
public sealed record GetConversationsQuery : IRequest<List<ConversationSummaryDTO>>;
