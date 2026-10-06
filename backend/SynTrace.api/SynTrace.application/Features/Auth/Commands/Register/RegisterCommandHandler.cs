using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Interfaces;

namespace SynTrace.Application.Features.Auth.Commands.Register
{
    public class RegisterCommandHandler : IRequestHandler<RegisterCommand, RegisterResponseDTO>
    {
        private readonly IRegisterService _registerService;
        public RegisterCommandHandler(IRegisterService registerService)
        {
            _registerService = registerService;
        }

        public async Task<RegisterResponseDTO> Handle(RegisterCommand command, CancellationToken cancellationToken)
        {
            return await _registerService.CreateFirstEmployeeAsync(command.Request);
        }
    }
}
