using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace SynTrace.Infrastructure.Integrations.Jira;

public static class JiraWebhookSecurity
{
    public static string GenerateSecret() =>
        Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();

    public static string Hash(string secret) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(secret)));

    public static bool VerifySecret(string? provided, string? storedHash)
    {
        if (string.IsNullOrEmpty(provided) || string.IsNullOrEmpty(storedHash)) return false;
        var a = Encoding.ASCII.GetBytes(Hash(provided).ToUpperInvariant());
        var b = Encoding.ASCII.GetBytes(storedHash.ToUpperInvariant());
        return CryptographicOperations.FixedTimeEquals(a, b);
    }

    /// <summary>Verifies the HS256 bearer token Jira puts on OAuth 2.0 webhooks (signature and expiry).</summary>
    public static bool VerifyJwt(string? authorizationHeader, string secret, DateTimeOffset now)
    {
        const string bearer = "Bearer ";
        if (string.IsNullOrEmpty(secret) || authorizationHeader is null
            || !authorizationHeader.StartsWith(bearer, StringComparison.OrdinalIgnoreCase)) return false;
        var parts = authorizationHeader[bearer.Length..].Trim().Split('.');
        if (parts.Length != 3) return false;
        try
        {
            using var header = JsonDocument.Parse(Base64UrlDecode(parts[0]));
            if (header.RootElement.Str("alg") != "HS256") return false;
            using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
            var expected = hmac.ComputeHash(Encoding.ASCII.GetBytes($"{parts[0]}.{parts[1]}"));
            if (!CryptographicOperations.FixedTimeEquals(expected, Base64UrlDecode(parts[2]))) return false;
            using var claims = JsonDocument.Parse(Base64UrlDecode(parts[1]));
            return claims.RootElement.Long("exp") is not { } exp || DateTimeOffset.FromUnixTimeSeconds(exp) > now;
        }
        catch (Exception ex) when (ex is FormatException or JsonException or ArgumentOutOfRangeException)
        {
            return false;
        }
    }

    private static byte[] Base64UrlDecode(string value)
    {
        var text = value.Replace('-', '+').Replace('_', '/');
        return Convert.FromBase64String(text.PadRight(text.Length + (4 - text.Length % 4) % 4, '='));
    }

    public static bool VerifyHmac(byte[] rawBody, string? signatureHeader, string secret)
    {
        if (string.IsNullOrWhiteSpace(signatureHeader) || string.IsNullOrEmpty(secret)) return false;

        const string prefix = "sha256=";
        var hex = signatureHeader.Trim();
        if (hex.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) hex = hex[prefix.Length..];

        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var expected = Convert.ToHexString(hmac.ComputeHash(rawBody)).ToLowerInvariant();

        return CryptographicOperations.FixedTimeEquals(
            Encoding.ASCII.GetBytes(expected),
            Encoding.ASCII.GetBytes(hex.ToLowerInvariant()));
    }
}
