using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Identity;

public static class JwtSessionValidator
{
    public const string VersionClaim = "syntrace_session_version";

    public static string Version(string stamp) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(stamp)));

    public static async Task ValidateAsync(TokenValidatedContext context)
    {
        var principal = context.Principal;
        var employeeId = principal?.FindFirstValue(ClaimTypes.NameIdentifier);
        var companyId = principal?.FindFirstValue("CompanyId");
        var claimedVersion = principal?.FindFirstValue(VersionClaim);
        if (string.IsNullOrEmpty(employeeId) || string.IsNullOrEmpty(companyId) || claimedVersion is not { Length: 64 })
        {
            context.Fail("Sign in again.");
            return;
        }

        var db = context.HttpContext.RequestServices.GetRequiredService<SynTraceDbContext>();
        var stamp = await db.Employees.AsNoTracking()
            .Where(x => x.Id == employeeId && x.CompanyId == companyId)
            .Select(x => x.SecurityStamp).SingleOrDefaultAsync(context.HttpContext.RequestAborted);
        if (string.IsNullOrEmpty(stamp) || !CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(claimedVersion), Encoding.ASCII.GetBytes(Version(stamp))))
            context.Fail("Sign in again.");
    }
}
