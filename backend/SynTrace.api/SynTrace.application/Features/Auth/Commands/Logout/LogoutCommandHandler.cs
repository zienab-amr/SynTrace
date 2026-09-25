using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Auth.Commands.Logout
{
    public class LogoutCommandHandler : IRequestHandler<LogoutCommand>
    {
        private readonly ITokenService _tokenService;
        public LogoutCommandHandler(ITokenService tokenService)
        {
            _tokenService = tokenService;
        }
        public async Task Handle(LogoutCommand command, CancellationToken cancellationToken)
        {
            await _tokenService.LogoutAsync(command.RefreshToken);
        }
    }
}
