using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Auth.Commands.RefreshToken
{
    public class RefreshTokenCommandHandler : IRequestHandler<RefreshTokenCommand , TokenResultDTO>
    {
        private readonly ITokenService _tokenService;

        public RefreshTokenCommandHandler(ITokenService tokenService)
        {
            _tokenService = tokenService;
        }
        public async Task<TokenResultDTO> Handle(RefreshTokenCommand command, CancellationToken cancellationToken)
        {
            return await _tokenService.RefreshTokens(command.RefreshToken);
        }

    }
}
