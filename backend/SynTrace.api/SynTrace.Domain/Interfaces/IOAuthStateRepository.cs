using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Interfaces;

public interface IOAuthStateRepository
{
    Task<string> CreateAsync(
        IntegrationProvider provider,
        OAuthStatePurpose purpose,
        string companyId,
        string employeeId,
        string? codeVerifier = null,
        CancellationToken cancellationToken = default);

    Task<ConsumedOAuthState?> TryConsumeAsync(
        string state,
        IntegrationProvider provider,
        OAuthStatePurpose? purpose = null,
        CancellationToken cancellationToken = default);
}

public sealed record ConsumedOAuthState(
    string CompanyId,
    string EmployeeId,
    OAuthStatePurpose Purpose,
    string? CodeVerifier);
