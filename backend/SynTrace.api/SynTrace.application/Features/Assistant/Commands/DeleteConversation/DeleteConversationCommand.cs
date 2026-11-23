using MediatR;
namespace SynTrace.Application.Features.Assistant.Commands.DeleteConversation;
public sealed record DeleteConversationCommand(string ConversationId) : IRequest;
