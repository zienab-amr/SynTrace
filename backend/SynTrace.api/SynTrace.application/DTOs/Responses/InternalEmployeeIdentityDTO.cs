namespace SynTrace.Application.DTOs.Responses;

/// <summary>
/// A SynTrace employee and their self-linked provider identities. A null value means
/// that no unambiguous, currently usable provider link was found.
/// No OAuth tokens or personal credentials are exposed.
/// </summary>
public sealed record InternalEmployeeIdentityDTO(
    string EmployeeId,
    string? JiraAccountId,
    long? GitHubUserId,
    string? GitHubLogin);
