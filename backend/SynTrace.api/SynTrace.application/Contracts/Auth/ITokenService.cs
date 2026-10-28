using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;

namespace SynTrace.Domain.Interfaces
{
    public interface ITokenService
    {

        public Task<TokenResultDTO> GenerateAccessToken(Employee request);

        public Task<RefreshToken> GenerateRefreshToken();

        public Task<TokenResultDTO> RefreshTokens(string refreshToken);
        public Task<TokenResultDTO> GenerateTokens(Employee employee);
        public Task LogoutAsync(string refreshToken);

    }
}
