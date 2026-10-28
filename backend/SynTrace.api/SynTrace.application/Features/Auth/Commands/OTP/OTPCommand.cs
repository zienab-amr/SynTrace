using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Requests;

namespace SynTrace.Application.Features.Auth.Commands.SendOTP
{
    public record SendOTPCommand(OTPRequestDTO Request) : IRequest;

    public record VerifyOTPCommand(VerifyOTPRequestDTO Request) : IRequest<bool>;
}
