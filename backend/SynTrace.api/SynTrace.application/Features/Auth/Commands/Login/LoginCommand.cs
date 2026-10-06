using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Auth.Commands.Login
{
    public record LoginCommand(LoginRequestDTO Request) : IRequest<TokenResultDTO>;
}
