using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public sealed class GitHubApiClient(
    IHttpClientFactory httpClientFactory,
    IOptions<GitHubOAuthOptions> options,
    IMemoryCache cache)
{
    internal const string HttpClientName = "SynTrace.GitHub";
    private static readonly Uri ApiRoot = new("https://api.github.com/");
    private static readonly Uri OAuthTokenEndpoint = new("https://github.com/login/oauth/access_token");
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<T> GetAsync<T>(string relativePath, string token, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, ApiUri(relativePath));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        request.Headers.Add("X-GitHub-Api-Version", "2022-11-28");
        return await SendAsync<T>(request, cancellationToken);
    }

    internal async Task<string> ExchangeUserCodeAsync(string code, string? codeVerifier, CancellationToken cancellationToken)
    {
        var config = options.Value;
        var form = new Dictionary<string, string>
        {
            ["client_id"] = config.ClientId,
            ["client_secret"] = config.ClientSecret,
            ["code"] = code,
            ["redirect_uri"] = config.RedirectUri
        };
        if (codeVerifier is not null)
            form["code_verifier"] = codeVerifier;

        using var request = new HttpRequestMessage(HttpMethod.Post, OAuthTokenEndpoint)
        {
            Content = new FormUrlEncodedContent(form)
        };
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        var response = await SendAsync<TokenResponse>(request, cancellationToken);
        if (response.Error is not null || string.IsNullOrWhiteSpace(response.AccessToken))
            throw new GitHubApiException("GitHub did not accept the authorization code.", HttpStatusCode.BadRequest);

        return response.AccessToken;
    }

    public async Task<string> GetInstallationTokenAsync(long installationId, long? repositoryId, CancellationToken cancellationToken)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(installationId);
        if (repositoryId is { } repo)
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(repo);
        var cacheKey = (typeof(GitHubApiClient), installationId, repositoryId);
        if (cache.TryGetValue<string>(cacheKey, out var existing) && !string.IsNullOrEmpty(existing))
            return existing;

        using var request = new HttpRequestMessage(HttpMethod.Post, ApiUri($"/app/installations/{installationId}/access_tokens"));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await CreateAppJwtAsync(cancellationToken));
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        request.Headers.Add("X-GitHub-Api-Version", "2022-11-28");
        var grant = new Dictionary<string, object>
        {
            ["permissions"] = new Dictionary<string, string>
            {
                ["contents"] = "read",
                ["pull_requests"] = "read",
                ["metadata"] = "read"
            }
        };
        if (repositoryId is { } id)
            grant["repository_ids"] = new[] { id };
        request.Content = JsonContent.Create(grant);

        var response = await SendAsync<TokenResponse>(request, cancellationToken);
        if (string.IsNullOrWhiteSpace(response.Token) || response.ExpiresAt <= DateTimeOffset.UtcNow)
            throw new GitHubApiException("GitHub returned an invalid installation token response.", HttpStatusCode.BadGateway);

        var expiry = response.ExpiresAt.AddMinutes(-3);
        if (expiry > DateTimeOffset.UtcNow)
            cache.Set(cacheKey, response.Token, expiry);
        return response.Token;
    }

    internal async Task<GitHubInstallation> GetInstallationAsync(long installationId, CancellationToken cancellationToken)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(installationId);
        var appJwt = await CreateAppJwtAsync(cancellationToken);
        return await GetAsync<GitHubInstallation>($"/app/installations/{installationId}", appJwt, cancellationToken);
    }

    internal async Task<IReadOnlyList<GitHubInstallation>> ListUserInstallationsAsync(string userToken, CancellationToken cancellationToken)
    {
        var result = new List<GitHubInstallation>();
        for (var page = 1; ; page++)
        {
            var response = await GetAsync<InstallationPage>($"/user/installations?per_page=100&page={page}", userToken, cancellationToken);
            result.AddRange(response.Installations);
            if (response.Installations.Count < 100 || result.Count >= response.TotalCount)
                return result;
        }
    }

    internal async Task<IReadOnlyList<GitHubRepository>> ListRepositoriesAsync(string path, string token, CancellationToken cancellationToken)
    {
        var result = new List<GitHubRepository>();
        for (var page = 1; ; page++)
        {
            var response = await GetAsync<RepositoryPage>($"{path}?per_page=100&page={page}", token, cancellationToken);
            result.AddRange(response.Repositories);
            if (response.Repositories.Count < 100 || result.Count >= response.TotalCount)
                return result;
        }
    }

    private async Task<T> SendAsync<T>(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        using var response = await httpClientFactory.CreateClient(HttpClientName)
            .SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            var retryAt = response.Headers.RetryAfter?.Date ?? (response.Headers.RetryAfter?.Delta is { } delta
                ? DateTimeOffset.UtcNow.Add(delta)
                : null);
            if (retryAt is null && response.Headers.TryGetValues("X-RateLimit-Remaining", out var remaining) &&
                remaining.FirstOrDefault() == "0" && response.Headers.TryGetValues("X-RateLimit-Reset", out var resets) &&
                long.TryParse(resets.FirstOrDefault(), NumberStyles.None, CultureInfo.InvariantCulture, out var reset) &&
                reset is > 0 and < 253402300800)
            {
                retryAt = DateTimeOffset.FromUnixTimeSeconds(reset);
            }
            throw new GitHubApiException("GitHub rejected or could not complete the request.", response.StatusCode, retryAt?.UtcDateTime);
        }

        try
        {
            var body = await response.Content.ReadFromJsonAsync<T>(JsonOptions, cancellationToken);
            return body ?? throw new GitHubApiException("GitHub returned an empty response.", HttpStatusCode.BadGateway);
        }
        catch (JsonException)
        {
            throw new GitHubApiException("GitHub returned an invalid response.", HttpStatusCode.BadGateway);
        }
    }

    private async Task<string> CreateAppJwtAsync(CancellationToken cancellationToken)
    {
        var config = options.Value;
        if (string.IsNullOrWhiteSpace(config.ClientId) || string.IsNullOrWhiteSpace(config.PrivateKeyPath))
            throw new GitHubApiException("GitHub App credentials are not configured.", HttpStatusCode.ServiceUnavailable);

        var now = DateTimeOffset.UtcNow;
        var header = Base64Url(Encoding.UTF8.GetBytes("""{"alg":"RS256","typ":"JWT"}"""));
        var claims = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new
        {
            iss = config.ClientId,
            iat = now.AddSeconds(-60).ToUnixTimeSeconds(),
            exp = now.AddMinutes(8).ToUnixTimeSeconds()
        }));
        var input = $"{header}.{claims}";
        using var rsa = RSA.Create();
        try
        {
            rsa.ImportFromPem(await File.ReadAllTextAsync(config.PrivateKeyPath, cancellationToken));
            return $"{input}.{Base64Url(rsa.SignData(Encoding.ASCII.GetBytes(input), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1))}";
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or ArgumentException or CryptographicException)
        {
            throw new GitHubApiException("The GitHub App private key is unavailable or invalid.", HttpStatusCode.ServiceUnavailable);
        }
    }

    public static string Base64Url(ReadOnlySpan<byte> bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static Uri ApiUri(string path)
    {
        if (!path.StartsWith('/') || path.StartsWith("//", StringComparison.Ordinal)
            || path.Contains('\\') || !Uri.TryCreate(ApiRoot, path, out var uri) || uri.Host != ApiRoot.Host)
            throw new ArgumentException("An API path relative to api.github.com is required.", nameof(path));
        return uri;
    }

    private sealed record TokenResponse(
        [property: JsonPropertyName("access_token")] string? AccessToken,
        string? Token,
        [property: JsonPropertyName("expires_at")] DateTimeOffset ExpiresAt,
        string? Error);

    private sealed record InstallationPage(
        [property: JsonPropertyName("total_count")] int TotalCount, IReadOnlyList<GitHubInstallation> Installations);

    private sealed record RepositoryPage(
        [property: JsonPropertyName("total_count")] int TotalCount, IReadOnlyList<GitHubRepository> Repositories);
}

public sealed class GitHubApiException(string message, HttpStatusCode statusCode, DateTime? retryAtUtc = null)
    : HttpRequestException(message, null, statusCode)
{
    public DateTime? RetryAtUtc { get; } = retryAtUtc;
}

internal sealed record GitHubAccount(long Id, string Login, string Type);
internal sealed record GitHubInstallation(
    long Id,
    [property: JsonPropertyName("app_id")] long AppId,
    GitHubAccount Account,
    [property: JsonPropertyName("suspended_at")] DateTimeOffset? SuspendedAt);
internal sealed record GitHubRepositoryPermissions(bool Admin);
internal sealed record GitHubRepository(
    long Id, string Name, GitHubAccount Owner,
    [property: JsonPropertyName("full_name")] string FullName,
    [property: JsonPropertyName("default_branch")] string? DefaultBranch,
    [property: JsonPropertyName("private")] bool IsPrivate, GitHubRepositoryPermissions? Permissions);
