using MediatR;
using SynTrace.Application.Contracts.Integrations.Jira;

namespace SynTrace.Application.Features.Integrations.Jira.Commands.CompleteCompanyJiraConnection;

public sealed class CompleteCompanyJiraConnectionCommandHandler
    : IRequestHandler<CompleteCompanyJiraConnectionCommand>
{
    private readonly IJiraOAuthService _service;

    public CompleteCompanyJiraConnectionCommandHandler(
        IJiraOAuthService service)
    {
        _service = service;
    }

    public Task Handle(
        CompleteCompanyJiraConnectionCommand request,
        CancellationToken cancellationToken)
    {
        return _service.CompleteCompanyJiraConnection(
            request.PendingId,
            request.CloudId,
            cancellationToken);
    }
}