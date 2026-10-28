using System;
using System.Collections.Generic;
using System.Text;
using MediatR;
using SynTrace.Domain.Entities;

namespace SynTrace.Application.Features.Auth.Commands.Logout
{
    public record LogoutCommand(string RefreshToken) : IRequest;
}
