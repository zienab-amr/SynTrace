using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity;

public sealed class OTPService(
    SynTraceDbContext db,
    ILookupNormalizer normalizer,
    IDataProtectionProvider protectionProvider,
    IEmailService email,
    ILogger<OTPService> logger) : IOTPService
{
    private const string Registration = "registration";
    private const string PasswordReset = "passwordReset";
    private static readonly TimeSpan SendWindow = TimeSpan.FromMinutes(15);
    private const int MaxSendsPerWindow = 5;
    private const int MaxAttempts = 5;
    private readonly IDataProtector _protector = protectionProvider.CreateProtector("SynTrace.IdentityCodes.v1");

    public async Task SendOTP(OTPRequestDTO requestDto, CancellationToken cancellationToken = default)
    {
        var purpose = ParsePurpose(requestDto.Purpose);
        var address = requestDto.Email.Trim();
        var normalized = Normalize(address);
        var now = DateTime.UtcNow;
        var key = Key(purpose, normalized);

        string? recipient;
        string code;
        await using (var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken))
        {
            var challenge = await db.Set<IdentityChallenge>().SingleOrDefaultAsync(x => x.Key == key, cancellationToken);
            if (challenge is null)
            {
                challenge = new IdentityChallenge { Key = key, SendWindowUtc = now };
                db.Add(challenge);
            }
            else if (now - challenge.SendWindowUtc >= SendWindow)
            {
                challenge.SendWindowUtc = now;
                challenge.SendsInWindow = 0;
            }

            // All addresses follow the same throttle, including unregistered reset addresses.
            if (challenge.SendsInWindow >= MaxSendsPerWindow || now - challenge.UpdatedAtUtc < TimeSpan.FromMinutes(1))
                throw new RequestFailureException(429, "Please wait before requesting another code.");

            var users = await db.Employees.AsNoTracking().Where(user => user.NormalizedEmail == normalized)
                .Select(user => new { user.Id, user.Email })
                .Take(2).ToListAsync(cancellationToken);

            recipient = purpose == Registration
                ? (users.Count == 0 ? address : null)
                : (users.Count == 1 ? users[0].Email : null);
            code = RandomNumberGenerator.GetInt32(100_000, 1_000_000).ToString(CultureInfo.InvariantCulture);
            challenge.SubjectId = purpose == PasswordReset && users.Count == 1 ? users[0].Id : null;
            challenge.ProtectedCode = recipient is null ? null : _protector.Protect(code);
            challenge.ProofHash = null;
            challenge.Attempts = 0;
            challenge.SendsInWindow++;
            challenge.UpdatedAtUtc = now;
            challenge.ExpiresAtUtc = now.AddMinutes(5);
            await db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }

        if (recipient is not null)
        {
            try
            {
                await email.SendOTP(recipient, code);
            }
            catch (System.Net.Mail.SmtpException exception)
            {
                // Avoid an SMTP response difference that would distinguish existing reset accounts.
                logger.LogWarning("Identity code email delivery failed ({StatusCode}).", exception.StatusCode);
            }
        }
    }

    public async Task<OtpVerificationResult> VerifyOTP(VerifyOTPRequestDTO requestDto, CancellationToken cancellationToken = default)
    {
        var result = await ConsumeAsync(
            Registration, requestDto.Email, null, requestDto.OTP, null, issueProof: true, cancellationToken);
        return new OtpVerificationResult(result is not null, result);
    }

    public async Task<bool> ConsumeRegistrationAsync(
        string email, string? verificationToken, string? code, CancellationToken cancellationToken = default) =>
        await ConsumeAsync(Registration, email, null, code, verificationToken, issueProof: false, cancellationToken) is not null;

    public async Task<bool> ConsumePasswordResetAsync(
        string email, string employeeId, string code, CancellationToken cancellationToken = default) =>
        await ConsumeAsync(PasswordReset, email, employeeId, code, null, issueProof: false, cancellationToken) is not null;

    private async Task<string?> ConsumeAsync(string purpose, string address, string? subjectId, string? code,
        string? issuedProof, bool issueProof, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var key = Key(purpose, Normalize(address));
        // Register and password reset may commit the challenge with the account change.
        await using var transaction = db.Database.CurrentTransaction is null
            ? await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct)
            : null;
        var eligible = db.Set<IdentityChallenge>().Where(x =>
            x.Key == key && x.SubjectId == subjectId && x.ExpiresAtUtc > now &&
            x.Attempts < MaxAttempts && (x.ProtectedCode != null || x.ProofHash != null));

        // The first write reserves one attempt and serializes simultaneous checks of the same code.
        if (await eligible.ExecuteUpdateAsync(update => update.SetProperty(x => x.Attempts, x => x.Attempts + 1), ct) != 1)
            return null;

        var row = db.Set<IdentityChallenge>().Where(x => x.Key == key);
        var challenge = await row.AsNoTracking().SingleAsync(ct);
        var matches = !string.IsNullOrEmpty(issuedProof)
            ? challenge.ProofHash is not null && FixedEquals(Hash(issuedProof), challenge.ProofHash)
            : VerifyProtectedCode(code, challenge.ProtectedCode);

        string? result = null;
        if (matches)
        {
            result = issueProof ? Convert.ToHexString(RandomNumberGenerator.GetBytes(32)) : string.Empty;
            var proofHash = issueProof ? Hash(result) : null;
            var expiry = issueProof ? now.AddMinutes(10) : now;
            await row.ExecuteUpdateAsync(update => update
                .SetProperty(x => x.ProtectedCode, (string?)null)
                .SetProperty(x => x.ProofHash, proofHash)
                .SetProperty(x => x.ExpiresAtUtc, expiry)
                .SetProperty(x => x.Attempts, 0), ct);
        }

        if (transaction is not null)
            await transaction.CommitAsync(ct);
        return result;
    }

    private string Normalize(string value) =>
        normalizer.NormalizeEmail(value.Trim()) ?? throw new RequestFailureException(400, "A valid email address is required.");

    private static string ParsePurpose(string value)
    {
        if (string.Equals(value, Registration, StringComparison.OrdinalIgnoreCase))
            return Registration;
        if (string.Equals(value, PasswordReset, StringComparison.OrdinalIgnoreCase))
            return PasswordReset;
        throw new RequestFailureException(400, "Use purpose 'registration' or 'passwordReset'.");
    }

    private bool VerifyProtectedCode(string? supplied, string? protectedCode)
    {
        if (supplied is not { Length: 6 } || protectedCode is null)
            return false;
        try
        {
            return FixedEquals(supplied, _protector.Unprotect(protectedCode));
        }
        catch (CryptographicException)
        {
            return false;
        }
    }

    private static string Key(string purpose, string emailAddress) => Hash(purpose + ":" + emailAddress);
    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    private static bool FixedEquals(string a, string b) =>
        CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(a), Encoding.UTF8.GetBytes(b));
}
