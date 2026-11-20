using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

/// <summary>
/// Calls Jira Cloud (https://api.atlassian.com/ex/jira/{cloudId}/...) on behalf of a stored connection.
/// Handles: token decryption, automatic refresh on 401 (rotating refresh tokens are persisted),
/// and 429 back-off. Tokens never appear in exceptions or logs.
/// </summary>
public sealed class JiraApiClient
{
    private const string ApiBase = "https://api.atlassian.com";
    private const int MaxAttempts = 4;

    private readonly SynTraceDbContext _db;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IOptions<JiraOAuthOptions> _options;
    private readonly IJiraOAuthConnectionRepository _repository;
    private readonly IDataProtector _protector;
    private readonly Dictionary<string, JiraConnection> _cache = new();

    public JiraApiClient(
        SynTraceDbContext db,
        IHttpClientFactory httpClientFactory,
        IOptions<JiraOAuthOptions> options,
        IJiraOAuthConnectionRepository repository,
        IDataProtectionProvider dataProtectionProvider)
    {
        _db = db;
        _httpClientFactory = httpClientFactory;
        _options = options;
        _repository = repository;
        // MUST be the same purpose string used by JiraOAuthService when encrypting.
        _protector = dataProtectionProvider.CreateProtector("SynTrace.Integrations.Jira.Tokens.v1");
    }

    /// <param name="pathAndQuery">Path after the site root, e.g. "/rest/api/3/project/search?startAt=0".</param>
    /// <returns>Parsed JSON, or null for an empty body (204). Caller disposes.</returns>
    public async Task<JsonDocument?> SendAsync(
        string connectionId,
        HttpMethod method,
        string pathAndQuery,
        object? body = null,
        CancellationToken cancellationToken = default)
    {
        var connection = await GetConnectionAsync(connectionId, cancellationToken);
        var accessToken = _protector.Unprotect(connection.EncryptedAccessToken);
        var refreshed = false;

        for (var attempt = 1; ; attempt++)
        {
            using var response = await SendOnceAsync(connection.CloudId, method, pathAndQuery, body, accessToken, cancellationToken);

            if (response.StatusCode == HttpStatusCode.Unauthorized && !refreshed)
            {
                refreshed = true;
                accessToken = await RefreshAccessTokenAsync(connection, cancellationToken);
                continue;
            }

            if (response.StatusCode == HttpStatusCode.TooManyRequests && attempt < MaxAttempts)
            {
                var delay = response.Headers.RetryAfter?.Delta ?? TimeSpan.FromSeconds(5 * attempt);
                await Task.Delay(delay > TimeSpan.FromSeconds(60) ? TimeSpan.FromSeconds(60) : delay, cancellationToken);
                continue;
            }

            var text = await response.Content.ReadAsStringAsync(cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var snippet = text.Length > 500 ? text[..500] : text;
                throw new HttpRequestException(
                    $"Jira API {(int)response.StatusCode} on {method} {pathAndQuery.Split('?')[0]}: {snippet}",
                    null,
                    response.StatusCode);
            }

            return string.IsNullOrWhiteSpace(text) ? null : JsonDocument.Parse(text);
        }
    }

    private async Task<HttpResponseMessage> SendOnceAsync(
        string cloudId, HttpMethod method, string pathAndQuery, object? body, string accessToken, CancellationToken ct)
    {
        var client = _httpClientFactory.CreateClient();
        var request = new HttpRequestMessage(method, $"{ApiBase}/ex/jira/{Uri.EscapeDataString(cloudId)}{pathAndQuery}");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        if (body is not null) request.Content = JsonContent.Create(body);
        return await client.SendAsync(request, ct);
    }

    private async Task<JiraConnection> GetConnectionAsync(string connectionId, CancellationToken ct)
    {
        if (_cache.TryGetValue(connectionId, out var cached)) return cached;

        var connection = await _db.JiraConnections.AsNoTracking()
            .SingleOrDefaultAsync(c => c.Id == connectionId && c.status, ct)
            ?? throw new InvalidOperationException("Active Jira connection was not found.");

        _cache[connectionId] = connection;
        return connection;
    }

    private async Task<string> RefreshAccessTokenAsync(JiraConnection connection, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(connection.EncryptedRefreshToken))
        {
            throw new InvalidOperationException(
                "Jira access token expired and no refresh token is stored. " +
                "Add the 'offline_access' scope and reconnect Jira.");
        }

        var refreshToken = _protector.Unprotect(connection.EncryptedRefreshToken);
        var opts = _options.Value;

        var client = _httpClientFactory.CreateClient();
        using var response = await client.PostAsJsonAsync(
            opts.TokenUrl,
            new
            {
                grant_type = "refresh_token",
                client_id = opts.ClientId,
                client_secret = opts.ClientSecret,
                refresh_token = refreshToken
            },
            ct);

        if (!response.IsSuccessStatusCode)
        {
            throw new HttpRequestException(
                $"Jira token refresh failed with status {(int)response.StatusCode}. The user must reconnect Jira.",
                null,
                response.StatusCode);
        }

        var token = await response.Content.ReadFromJsonAsync<JiraOAuthTokenResponse>(cancellationToken: ct);
        if (token is null || string.IsNullOrWhiteSpace(token.AccessToken))
            throw new InvalidOperationException("Jira returned an invalid refresh response.");

        var encAccess = _protector.Protect(token.AccessToken);
        // Atlassian rotates refresh tokens: the new one MUST be stored or the next refresh fails.
        var encRefresh = string.IsNullOrWhiteSpace(token.RefreshToken) ? null : _protector.Protect(token.RefreshToken);

        await _repository.UpdateConnectionTokensAsync(connection.Id, encAccess, encRefresh);

        connection.EncryptedAccessToken = encAccess;
        if (encRefresh is not null) connection.EncryptedRefreshToken = encRefresh;

        return token.AccessToken;
    }
}
