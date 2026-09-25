using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Auth.Commands.Login
{
    public class LoginCommandHandler : IRequestHandler<LoginCommand, TokenResultDTO>
    {
        private readonly ILoginService _loginService;
        public LoginCommandHandler(ILoginService loginService)
        {
            _loginService = loginService;
        }

        public async Task<TokenResultDTO> Handle(LoginCommand command, CancellationToken cancellationToken)
        {
            return await _loginService.GetEmployeeByEmail(command.Request);
        }
    }
}
