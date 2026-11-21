using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities.Integrations;
using SynTrace.Domain.Enums;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories;

public sealed class OAuthStateRepository : IOAuthStateRepository
{
    private static readonly TimeSpan StateLifetime = TimeSpan.FromMinutes(5);
    private readonly SynTraceDbContext _context;
    private readonly IDataProtector _codeVerifierProtector;

    public OAuthStateRepository(SynTraceDbContext context, IDataProtectionProvider dataProtectionProvider)
    {
        _context = context;
        _codeVerifierProtector = dataProtectionProvider.CreateProtector("SynTrace.Integrations.OAuthState.Pkce.v1");
    }

    public async Task<string> CreateAsync(
        IntegrationProvider provider,
        OAuthStatePurpose purpose,
        string companyId,
        string employeeId,
        string? codeVerifier = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(companyId);
        ArgumentException.ThrowIfNullOrWhiteSpace(employeeId);

        var state = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        _context.OAuthStates.Add(new OAuthState
        {
            StateHash = ComputeHash(state),
            Provider = provider,
            Purpose = purpose,
            CompanyId = companyId,
            EmployeeId = employeeId,
            EncryptedCodeVerifier = codeVerifier is null ? null : _codeVerifierProtector.Protect(codeVerifier),
            ExpiresAt = DateTime.UtcNow.Add(StateLifetime)
        });

        await _context.SaveChangesAsync(cancellationToken);
        return state;
    }

    public async Task<ConsumedOAuthState?> TryConsumeAsync(
        string state,
        IntegrationProvider provider,
        OAuthStatePurpose? purpose = null,
        CancellationToken cancellationToken = default)
    {
        // Accept previously issued Jira state values until they expire, along with the new format.
        if (string.IsNullOrWhiteSpace(state) || state.Length > 128)
            return null;

        var hash = ComputeHash(state);
        var now = DateTime.UtcNow;
        var matchingState = _context.OAuthStates.Where(row =>
            row.StateHash == hash && row.Provider == provider &&
            (purpose == null || row.Purpose == purpose) &&
            (row.Purpose == OAuthStatePurpose.Company || row.Purpose == OAuthStatePurpose.Employee));

        // The comparison and update happen in a single database statement. Only one callback can win.
        var updated = await matchingState
            .Where(row => row.ConsumedAt == null && row.ExpiresAt > now)
            .ExecuteUpdateAsync(update => update.SetProperty(row => row.ConsumedAt, now), cancellationToken);

        if (updated != 1)
            return null;

        var result = await matchingState.AsNoTracking()
            .Select(row => new { row.CompanyId, row.EmployeeId, row.Purpose, row.EncryptedCodeVerifier })
            .SingleOrDefaultAsync(cancellationToken);

        if (result is null)
            return null;

        var codeVerifier = result.EncryptedCodeVerifier is null
            ? null
            : _codeVerifierProtector.Unprotect(result.EncryptedCodeVerifier);

        return new ConsumedOAuthState(result.CompanyId, result.EmployeeId, result.Purpose, codeVerifier);
    }

    private static string ComputeHash(string state) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(state)));
}
