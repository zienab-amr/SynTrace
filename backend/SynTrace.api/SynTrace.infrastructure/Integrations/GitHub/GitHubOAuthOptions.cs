namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class GitHubOAuthOptions
{
    public const string SectionName = "GithubOAuth";

    public long AppId { get; set; }
    public string AppSlug { get; set; } = string.Empty;
    public string ClientId { get; set; } = string.Empty;
    public string ClientSecret { get; set; } = string.Empty;
    public string PrivateKeyPath { get; set; } = string.Empty;
    public string RedirectUri { get; set; } = string.Empty;
    public string FrontendRedirectUri { get; set; } = string.Empty;
}
