using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Auth.Commands.RefreshToken
{
    public record RefreshTokenCommand(string RefreshToken) : IRequest<TokenResultDTO>;
    
}
