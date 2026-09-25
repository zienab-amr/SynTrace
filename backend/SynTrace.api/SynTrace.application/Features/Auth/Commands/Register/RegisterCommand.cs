using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Auth.Commands.Register
{
    public record RegisterCommand(RegisterRequestDTO Request) : IRequest<RegisterResponseDTO>;

}
