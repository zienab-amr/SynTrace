using MediatR;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Auth.Commands.SendOTP;

public sealed record SendOTPCommand(OTPRequestDTO Request) : IRequest;
public sealed record VerifyOTPCommand(VerifyOTPRequestDTO Request) : IRequest<OtpVerificationResult>;
