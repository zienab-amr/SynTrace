using System.Text.RegularExpressions;
using System.Text;

namespace SynTrace.Infrastructure.Integrations.GitHub;

internal static partial class GitHubContentPolicy
{
    private static readonly HashSet<string> CodeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".c", ".cc", ".cpp", ".cs", ".css", ".dart", ".fs", ".go", ".h", ".hpp", ".html", ".java",
        ".js", ".jsx", ".kt", ".kts", ".lua", ".md", ".mjs", ".php", ".py", ".rb", ".rs",
        ".sh", ".sql", ".swift", ".ts", ".tsx", ".vue"
    };

    private static readonly HashSet<string> DeniedDirectories = new(StringComparer.OrdinalIgnoreCase)
    {
        "node_modules", "vendor", "dist", "build", "bin", "obj", ".git", ".ssh", ".aws", ".kube", "secrets"
    };

    public static bool IsAllowedCodePath(string path)
    {
        if (path.Length > 1024 || path.Contains('\\') || path.Any(char.IsControl))
            return false;

        var components = path.Split('/');
        if (components.Any(x => string.IsNullOrWhiteSpace(x) || x is "." or ".." || DeniedDirectories.Contains(x)))
            return false;

        var file = components[^1];
        return !file.StartsWith('.') && !file.Contains(".min.", StringComparison.OrdinalIgnoreCase)
            && !file.Contains(".generated.", StringComparison.OrdinalIgnoreCase)
            && !SensitivePath().IsMatch(path) && !Credential().IsMatch(path)
            && CodeExtensions.Contains(Path.GetExtension(file));
    }

    public static string? Clean(string? value, int limit = 8_192)
    {
        if (value is null)
            return null;

        var content = value.Length > limit ? value[..limit] : value;
        content = PemBlock().Replace(content, match => "[REDACTED PRIVATE KEY]" + string.Concat(match.Value.Where(x => x is '\r' or '\n')));
        content = Credential().Replace(content, "[REDACTED]");
        content = SensitiveAssignment().Replace(content, m => m.Groups[1].Value + "[REDACTED]");
        return content;
    }

    public static string[] JiraKeys(params string?[] fields) => fields.Where(x => x is not null)
        .SelectMany(x => JiraIssueKey().Matches(x!).Select(m => m.Value.ToUpperInvariant()))
        .Distinct(StringComparer.Ordinal).Take(30).ToArray();

    public static bool TryReadText(byte[] bytes, out string text)
    {
        text = string.Empty;
        if (bytes.Contains((byte)0))
            return false;
        try
        {
            text = new UTF8Encoding(false, true).GetString(bytes);
            return true;
        }
        catch (DecoderFallbackException)
        {
            return false;
        }
    }

    [GeneratedRegex(@"(?:^|[/_.-])(?:appsettings|credential[s]?|secret[s]?|keystore|private[-_]key|dotenv|id_rsa|id_ed25519)(?:$|[/_.-])", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex SensitivePath();

    [GeneratedRegex(@"\b(?:gh[pousr]_[A-Za-z0-9_]{16,}|github_pat_[A-Za-z0-9_]{16,}|(?:AKIA|ASIA)[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]{12,}|sk_(?:live|test)_[A-Za-z0-9]{12,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{35}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,})\b", RegexOptions.CultureInvariant)]
    private static partial Regex Credential();

    [GeneratedRegex(@"-----BEGIN [^-\r\n]*PRIVATE KEY-----[\s\S]*?(?:-----END [^-\r\n]*PRIVATE KEY-----|\z)", RegexOptions.CultureInvariant)]
    private static partial Regex PemBlock();

    [GeneratedRegex("""(?ix)(\b[a-z0-9_-]*(?:api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|password|pwd|secret|authorization|connection[_-]?string)\b["']?[ \t]*[:=][ \t]*)(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s,;\)\}\]]+)""", RegexOptions.CultureInvariant)]
    private static partial Regex SensitiveAssignment();

    [GeneratedRegex(@"(?<![A-Z0-9])[A-Z][A-Z0-9]{1,31}-[0-9]{1,12}(?![A-Z0-9])", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex JiraIssueKey();
}
