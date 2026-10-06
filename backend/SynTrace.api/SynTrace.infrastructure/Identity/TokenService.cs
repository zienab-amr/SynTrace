using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using SynTrace.Application.DTOs;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using Microsoft.EntityFrameworkCore;
using SynTrace.Infrastructure.Persistence.Context;
using Microsoft.AspNetCore.Identity;

namespace SynTrace.Infrastructure.Identity
{
    public class TokenService : ITokenService
    {

        private readonly IConfiguration _configuration;
        private readonly SynTraceDbContext _context;
        private readonly UserManager<Employee> _userManager;

        public TokenService(IConfiguration configuration, SynTraceDbContext context, UserManager<Employee> userManager)
        {
            _configuration = configuration;
            _context = context;
            _userManager = userManager;
        }
        public async Task<TokenResultDTO> GenerateAccessToken(Employee request)
        {
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, request.Id.ToString()),

                // Multi-Tenant
                new Claim("CompanyId", request.CompanyId.ToString()),

            };
            var roles = await _userManager.GetRolesAsync(request);

            foreach (var role in roles)
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["jwt:key"]));

            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var expires = DateTime.UtcNow.AddDays(Convert.ToDouble(_configuration["jwt:DurationInDays"]));

            var token = new JwtSecurityToken(
                issuer: _configuration["jwt:issuer"],
                audience: _configuration["jwt:audience"],
                expires: expires,
                claims: claims,
                signingCredentials: creds
            );

            return new TokenResultDTO
            {
                AccessToken = new JwtSecurityTokenHandler().WriteToken(token),
                AccessTokenExpiration = expires
            };

        }

        public async Task<RefreshToken> GenerateRefreshToken()
        {
            var randomNumber = RandomNumberGenerator.GetBytes(64);

            return new RefreshToken
            {
                Id = Guid.NewGuid().ToString(),
                Token = Convert.ToBase64String(randomNumber),
                CreatedOn = DateTime.UtcNow,
                UpdatedOn = DateTime.UtcNow,
                ExpiredDate = DateTime.UtcNow.AddDays(30)
            };
        }

        public async Task<TokenResultDTO> GenerateTokens(Employee employee)
        {
            var accessToken = await GenerateAccessToken(employee);

            var refreshToken = await GenerateRefreshToken();

            refreshToken.EmployeeId = employee.Id;

            await _context.RefreshTokens.AddAsync(refreshToken);

            await _context.SaveChangesAsync();

            return new TokenResultDTO
            {
                AccessToken = accessToken.AccessToken,
                AccessTokenExpiration = accessToken.AccessTokenExpiration,

                RefreshToken = refreshToken.Token,
                RefreshTokenExpiration = refreshToken.ExpiredDate
            };
        }

        public async Task<TokenResultDTO> RefreshTokens(string refreshToken)
        {
            var oldToken = await _context.RefreshTokens
                .FirstOrDefaultAsync(x => x.Token == refreshToken);

            if (oldToken == null)
                throw new InvalidOperationException("Invalid refresh token.");

            if (oldToken.IsRevoked)
                throw new InvalidOperationException("Refresh token has been revoked.");

            if (oldToken.IsExpired)
                throw new InvalidOperationException("Refresh token has expired.");

            var employee = await _context.Employees
                .FirstOrDefaultAsync(x => x.Id == oldToken.EmployeeId);

            if (employee == null)
                throw new InvalidOperationException("Employee not found.");

            // Revoke old token
            oldToken.RevokedOn = DateTime.UtcNow;
            oldToken.UpdatedOn = DateTime.UtcNow;

            // Generate new tokens
            var accessToken = await GenerateAccessToken(employee);

            var newRefreshToken = await GenerateRefreshToken();

            newRefreshToken.EmployeeId = employee.Id;

            await _context.RefreshTokens.AddAsync(newRefreshToken);

            await _context.SaveChangesAsync();

            return new TokenResultDTO
            {
                AccessToken = accessToken.AccessToken,
                AccessTokenExpiration = accessToken.AccessTokenExpiration,

                RefreshToken = newRefreshToken.Token,
                RefreshTokenExpiration = newRefreshToken.ExpiredDate
            };
        }

        public async Task LogoutAsync(string refreshToken)
        {
            var token = await _context.RefreshTokens.FirstOrDefaultAsync(r => r.Token == refreshToken);

            if (token == null)
                throw new InvalidOperationException("Invalid refresh token.");

            if (token.IsRevoked)
                return;

            token.RevokedOn = DateTime.UtcNow;
            token.UpdatedOn = DateTime.UtcNow;


            await _context.SaveChangesAsync();
        }
    }
}
