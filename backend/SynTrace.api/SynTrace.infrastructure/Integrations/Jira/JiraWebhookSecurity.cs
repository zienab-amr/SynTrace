using System.Security.Cryptography;
using System.Text;

namespace SynTrace.Infrastructure.Integrations.Jira;

public static class JiraWebhookSecurity
{
    public static string GenerateSecret() =>
        Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();

    public static string Hash(string secret) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(secret)));

    /// <summary>Constant-time comparison of SHA-256(provided) with the stored hash.</summary>
    public static bool VerifySecret(string? provided, string? storedHash)
    {
        if (string.IsNullOrEmpty(provided) || string.IsNullOrEmpty(storedHash)) return false;
        var a = Encoding.ASCII.GetBytes(Hash(provided).ToUpperInvariant());
        var b = Encoding.ASCII.GetBytes(storedHash.ToUpperInvariant());
        return CryptographicOperations.FixedTimeEquals(a, b);
    }

    /// <summary>Verifies "X-Hub-Signature: sha256=&lt;hex&gt;" = HMAC-SHA256(rawBody, secret).</summary>
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
