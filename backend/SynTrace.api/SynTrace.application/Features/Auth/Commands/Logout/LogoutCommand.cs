using System.ComponentModel.DataAnnotations;
using MediatR;

namespace SynTrace.Application.Features.Auth.Commands.Logout;

public sealed record LogoutCommand([Required, StringLength(512)] string RefreshToken) : IRequest;
