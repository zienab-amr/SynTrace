namespace SynTrace.Application.DTOs.Requests;

public sealed record CompleteCompanyJiraConnectionRequest(
    string PendingId,
    string CloudId
);