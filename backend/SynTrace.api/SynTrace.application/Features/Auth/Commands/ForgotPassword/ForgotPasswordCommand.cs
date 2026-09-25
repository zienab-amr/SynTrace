using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Requests;

namespace SynTrace.Application.Features.Auth.Commands.ForgotPassword
{
    public record ForgotPasswordCommand(ForgotPasswordRequestDTO Request) : IRequest;

}
