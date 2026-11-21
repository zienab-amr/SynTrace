using System.Data;
using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity;

public sealed class TokenService(IConfiguration config, SynTraceDbContext db) : ITokenService
{
    public async Task<TokenResultDTO> GenerateAccessToken(Employee employee)
    {
        if (string.IsNullOrEmpty(employee.SecurityStamp))
            throw new RequestFailureException(401, "Sign in again.");
        var roleNames = await (from memberRole in db.UserRoles
            join role in db.Roles on memberRole.RoleId equals role.Id
            where memberRole.UserId == employee.Id && role.CompanyId == employee.CompanyId && role.Name != null
            select role.Name!).ToListAsync();
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, employee.Id),
            new("CompanyId", employee.CompanyId),
            new(JwtSessionValidator.VersionClaim, JwtSessionValidator.Version(employee.SecurityStamp))
        };
        claims.AddRange(roleNames.Select(role => new Claim(ClaimTypes.Role, role)));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(
            config["jwt:key"] ?? throw new InvalidOperationException("JWT signing is not configured.")));
        var expires = DateTime.UtcNow.AddDays(Convert.ToDouble(config["jwt:DurationInDays"], CultureInfo.InvariantCulture));
        var jwt = new JwtSecurityToken(
            config["jwt:issuer"], config["jwt:audience"], claims, expires: expires,
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
        return new TokenResultDTO
        {
            AccessToken = new JwtSecurityTokenHandler().WriteToken(jwt),
            AccessTokenExpiration = expires
        };
    }

    public Task<RefreshToken> GenerateRefreshToken()
    {
        var now = DateTime.UtcNow;
        return Task.FromResult(new RefreshToken
        {
            Id = Guid.NewGuid().ToString(),
            Token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64)),
            CreatedOn = now, UpdatedOn = now, ExpiredDate = now.AddDays(30)
        });
    }

    public async Task<TokenResultDTO> GenerateTokens(Employee employee)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var current = await db.Employees.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Id == employee.Id && x.CompanyId == employee.CompanyId);
        if (current is null || current.SecurityStamp != employee.SecurityStamp)
            throw new RequestFailureException(401, "Sign in again.");

        var response = await IssueAsync(current);
        await transaction.CommitAsync();
        return response;
    }

    public async Task<TokenResultDTO> RefreshTokens(string refreshToken)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var now = DateTime.UtcNow;
        var old = await FindRefreshTokenAsync(refreshToken);
        if (old is null || old.IsRevoked || old.ExpiredDate <= now)
            throw InvalidRefreshToken();

        var employee = await db.Employees.AsNoTracking().SingleOrDefaultAsync(x => x.Id == old.EmployeeId);
        if (employee is null)
            throw InvalidRefreshToken();

        var revoked = await db.RefreshTokens.Where(x => x.Id == old.Id && x.RevokedOn == null && x.ExpiredDate > now)
            .ExecuteUpdateAsync(update => update.SetProperty(x => x.RevokedOn, now).SetProperty(x => x.UpdatedOn, now));
        if (revoked != 1)
            throw InvalidRefreshToken();

        var response = await IssueAsync(employee);
        await transaction.CommitAsync();
        return response;
    }

    public async Task LogoutAsync(string refreshToken)
    {
        var token = await FindRefreshTokenAsync(refreshToken);
        if (token is null)
            return;

        var now = DateTime.UtcNow;
        await db.RefreshTokens.Where(x => x.Id == token.Id && x.RevokedOn == null)
            .ExecuteUpdateAsync(update => update.SetProperty(x => x.RevokedOn, now).SetProperty(x => x.UpdatedOn, now));
    }

    private async Task<TokenResultDTO> IssueAsync(Employee employee)
    {
        var access = await GenerateAccessToken(employee);
        var refresh = await GenerateRefreshToken();
        refresh.EmployeeId = employee.Id;
        var clientToken = refresh.Token;
        refresh.Token = Digest(clientToken);
        await db.RefreshTokens.AddAsync(refresh);
        await db.SaveChangesAsync();
        return new TokenResultDTO
        {
            AccessToken = access.AccessToken,
            AccessTokenExpiration = access.AccessTokenExpiration,
            RefreshToken = clientToken,
            RefreshTokenExpiration = refresh.ExpiredDate
        };
    }

    private async Task<RefreshToken?> FindRefreshTokenAsync(string candidate)
    {
        if (candidate.Length is < 64 or > 128 || candidate.Contains(':'))
            return null;

        var hash = Digest(candidate);
        var matches = await db.RefreshTokens.AsNoTracking()
            .Where(x => x.Token == hash || x.Token == candidate).Take(2).ToListAsync();
        // Existing sessions can rotate their old stored tokens into digests.
        return matches.FirstOrDefault(x => x.Token == hash || x.Token == candidate);
    }

    private static string Digest(string candidate) =>
        "sha256:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(candidate)));

    private static RequestFailureException InvalidRefreshToken() => new(401, "Invalid or expired refresh token.");
}
