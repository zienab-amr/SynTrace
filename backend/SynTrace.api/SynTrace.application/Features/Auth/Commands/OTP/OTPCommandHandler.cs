using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Auth.Commands.SendOTP
{
    public class SendOTPCommandHandler : IRequestHandler<SendOTPCommand>, IRequestHandler<VerifyOTPCommand, bool>
    {
        private readonly IOTPService _otpService;
        public SendOTPCommandHandler(IOTPService otpService)
        {
            _otpService = otpService;
        }
        public async Task Handle(SendOTPCommand command, CancellationToken cancellationToken)
        {
            await _otpService.SendOTP(command.Request);
        }   

        public async Task<bool> Handle(VerifyOTPCommand command, CancellationToken cancellationToken)
        {
            return await _otpService.VerifyOTP(command.Request);
        }

    }


}
