using MediatR;
using SynTrace.Application.Contracts;
namespace SynTrace.Application.Features.Assistant.Commands.DeleteConversation;
public sealed class DeleteConversationCommandHandler(IConversationService service)
    : IRequestHandler<DeleteConversationCommand>
{
    public async Task Handle(DeleteConversationCommand request, CancellationToken ct)
        => await service.DeleteConversationAsync(request.ConversationId, ct);
}
