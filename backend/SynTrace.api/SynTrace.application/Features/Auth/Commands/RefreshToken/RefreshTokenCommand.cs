using System.ComponentModel.DataAnnotations;
using MediatR;
using SynTrace.Application.DTOs.Responses;

namespace SynTrace.Application.Features.Auth.Commands.RefreshToken;

public sealed record RefreshTokenCommand([Required, StringLength(512)] string RefreshToken) : IRequest<TokenResultDTO>;
