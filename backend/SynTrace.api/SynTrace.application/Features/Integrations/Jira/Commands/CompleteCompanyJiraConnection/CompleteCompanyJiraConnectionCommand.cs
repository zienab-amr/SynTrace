using MediatR;

namespace SynTrace.Application.Features.Integrations.Jira.Commands.CompleteCompanyJiraConnection;

public sealed record CompleteCompanyJiraConnectionCommand(
    string PendingId,
    string CloudId) : IRequest;