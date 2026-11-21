using SynTrace.Application.DTOs.Requests;

namespace SynTrace.Domain.Interfaces;

public sealed record OtpVerificationResult(bool Verified, string? VerificationToken);

public interface IOTPService
{
    Task SendOTP(OTPRequestDTO requestDto, CancellationToken cancellationToken = default);
    Task<OtpVerificationResult> VerifyOTP(VerifyOTPRequestDTO requestDto, CancellationToken cancellationToken = default);
    Task<bool> ConsumeRegistrationAsync(string email, string? verificationToken, string? code, CancellationToken cancellationToken = default);
    Task<bool> ConsumePasswordResetAsync(string email, string employeeId, string code, CancellationToken cancellationToken = default);
}
