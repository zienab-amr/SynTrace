using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Auth.Commands.SendOTP;

public sealed class OTPCommandHandler(IOTPService otpService) :
    IRequestHandler<SendOTPCommand>, IRequestHandler<VerifyOTPCommand, OtpVerificationResult>
{
    public Task Handle(SendOTPCommand command, CancellationToken cancellationToken) =>
        otpService.SendOTP(command.Request, cancellationToken);

    public Task<OtpVerificationResult> Handle(VerifyOTPCommand command, CancellationToken cancellationToken) =>
        otpService.VerifyOTP(command.Request, cancellationToken);
}
