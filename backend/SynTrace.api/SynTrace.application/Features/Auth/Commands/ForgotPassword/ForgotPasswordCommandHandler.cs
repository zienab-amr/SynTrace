using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.Contracts.Auth;

namespace SynTrace.Application.Features.Auth.Commands.ForgotPassword
{
    public class ForgotPasswordCommandHandler : IRequestHandler<ForgotPasswordCommand>
    {
        private readonly IForgotPasswordService _forgotPasswordService;
        public ForgotPasswordCommandHandler(IForgotPasswordService forgotPasswordService)
        {
            _forgotPasswordService = forgotPasswordService;
        }
        public async Task Handle(ForgotPasswordCommand command, CancellationToken cancellationToken)
        {
            await _forgotPasswordService.ForgotPasswordAsync(command.Request);
        }
    }
}
