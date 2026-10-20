using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Integrations.Jira;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Options;

namespace SynTrace.Infrastructure.Services.Integrations.Jira
{
    public class JiraOAuthService : IJiraOAuthService
    {
        private readonly IOptions<JiraOAuthOptions> _options;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IJiraOAuthConnectionRepository _jiraOAuthConnectionRepository;
        private readonly ICurrentTenant _currentTenant;
        private readonly ICurrentEmployee _currentEmployee;
        private readonly IDataProtector _tokenProtector;
        public JiraOAuthService(
            IOptions<JiraOAuthOptions> options,
            IHttpClientFactory httpClientFactory,
            ICurrentTenant currentTenant,
            ICurrentEmployee currentEmployee,
            IJiraOAuthConnectionRepository jiraOAuthConnectionRepository,
            IDataProtectionProvider dataProtectionProvider
            )
        {
            _options = options;
            _httpClientFactory = httpClientFactory;
            _currentTenant = currentTenant;
            _currentEmployee = currentEmployee;
            _jiraOAuthConnectionRepository = jiraOAuthConnectionRepository;
            _tokenProtector = dataProtectionProvider.CreateProtector("SynTrace.Integrations.Jira.Tokens.v1");
        }

        public async Task<string> ConnectJira()
        {
            var state = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));

            var encodedState = Uri.EscapeDataString(state);

            var authorizationUrl = $"{_options.Value.AuthorizationUrl}?"
                                    + $"audience={Uri.EscapeDataString(_options.Value.Audience)}&"
                                    + $"client_id={Uri.EscapeDataString(_options.Value.ClientId)}&"
                                    + $"scope={Uri.EscapeDataString(string.Join(" ", _options.Value.Scopes))}&"
                                    + $"redirect_uri={Uri.EscapeDataString(_options.Value.RedirectUri)}&"
                                    + $"state={encodedState}&"
                                    + "response_type=code&"
                                    + "prompt=consent";

            var stateHash = ComputeHash(state);
            var newState = new JiraOAuthState
            {
                JiraOAuthStateId = Guid.NewGuid().ToString(),
                StateHash = stateHash,
                EmployeeId = _currentEmployee.EmployeeId,
                CompanyId = _currentTenant.CompanyId,
                ExpiresAt = DateTime.UtcNow.AddMinutes(5),
                ConsumedAt = null
            };
            await _jiraOAuthConnectionRepository.CreateState(newState);

            return authorizationUrl;
        }

        public async Task CallBack(string code, string state, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(state))
                throw new ArgumentException("OAuth state is required.", nameof(state));

            if (string.IsNullOrWhiteSpace(code))
                throw new ArgumentException("OAuth code is required.", nameof(code));

            var stateHash = ComputeHash(state);

            var oauthState =
                await _jiraOAuthConnectionRepository.TryConsumeState(stateHash);

            if (oauthState is null)
            {
                throw new InvalidOperationException(
                    "Invalid, expired, or already-used OAuth state.");
            }

            // 1. Exchange authorization code for tokens.
            var token = await ExchangeCodeForTokenAsync(
                code, cancellationToken);

            // 2. Get Jira sites accessible to this OAuth connection.
            var resources = await GetAccessibleResourcesAsync(
                token.AccessToken, cancellationToken);

            if (resources.Count == 0)
            {
                throw new InvalidOperationException(
                    "No accessible Jira sites were found for this account.");
            }

            // 3. For now, use the first site.
            // If multiple sites are available, add an explicit selection flow.
            var selectedResource = resources[0];

            // 4. Protect tokens before storing them.
            var encryptedAccessToken =
                _tokenProtector.Protect(token.AccessToken);

            var encryptedRefreshToken =
                string.IsNullOrWhiteSpace(token.RefreshToken)
                    ? null
                    : _tokenProtector.Protect(token.RefreshToken);

            // 5. Get the actual Jira account ID.
            var jiraAccountId = await GetJiraAccountIdAsync(
                selectedResource.Id,
                token.AccessToken,
                cancellationToken);

            // 6. Create the connection.
            var jiraConnection = new JiraConnection
            {
                Id = Guid.NewGuid().ToString(),

                JiraAccountId = jiraAccountId,
                CloudId = selectedResource.Id,
                SiteUrl = selectedResource.Url,

                EncryptedAccessToken = encryptedAccessToken,
                EncryptedRefreshToken = encryptedRefreshToken,

                ConnectedByEmployeeId = oauthState.EmployeeId,
                CompanyId = oauthState.CompanyId,

                status = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            // 7. Save the connection.
            await _jiraOAuthConnectionRepository.CreateConnection(
                jiraConnection);
        }



        private async Task<JiraOAuthTokenResponse> ExchangeCodeForTokenAsync(string code, CancellationToken cancellationToken)
        {
            var client = _httpClientFactory.CreateClient();
            var TokenUri = _options.Value.TokenUrl;

            var request = new JiraOAuthTokenRequest
            {
                GrantType = "authorization_code",
                ClientId = _options.Value.ClientId,
                ClientSecret = _options.Value.ClientSecret,
                Code = code,
                RedirectUri = _options.Value.RedirectUri

            };

            using var response = await client.PostAsJsonAsync(TokenUri, request, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                throw new HttpRequestException(
                    $"Jira token exchange failed with HTTP status " +
                    $"{(int)response.StatusCode} ({response.StatusCode}).");
            }

            var token = await response.Content.ReadFromJsonAsync<JiraOAuthTokenResponse>(cancellationToken: cancellationToken);

            if (token is null ||
            string.IsNullOrWhiteSpace(token.AccessToken))
            {
                throw new InvalidOperationException(
                    "The OAuth provider returned an invalid token response.");
            }

            return token;


        }

        private static string ComputeHash(string data)
        {
            var hash = SHA256.HashData(
                Encoding.UTF8.GetBytes(data));

            return Convert.ToHexString(hash);
        }

        private async Task<List<JiraAccessibleResourceResponse>>
    GetAccessibleResourcesAsync(
        string accessToken,
        CancellationToken cancellationToken)
        {
            var client = _httpClientFactory.CreateClient();

            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                "https://api.atlassian.com/oauth/token/accessible-resources");

            request.Headers.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue(
                    "Bearer", accessToken);

            using var response = await client.SendAsync(
                request, cancellationToken);

            response.EnsureSuccessStatusCode();

            var resources =
                await response.Content.ReadFromJsonAsync<
                    List<JiraAccessibleResourceResponse>>(
                        cancellationToken: cancellationToken);

            return resources ?? [];
        }

        private async Task<string> GetJiraAccountIdAsync(
    string cloudId,
    string accessToken,
    CancellationToken cancellationToken)
        {
            var client = _httpClientFactory.CreateClient();

            var requestUrl =
                $"https://api.atlassian.com/ex/jira/{Uri.EscapeDataString(cloudId)}/rest/api/3/myself";

            using var request = new HttpRequestMessage(
                HttpMethod.Get,
                requestUrl);

            request.Headers.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue(
                    "Bearer",
                    accessToken);

            using var response = await client.SendAsync(
                request,
                cancellationToken);

            response.EnsureSuccessStatusCode();

            var user = await response.Content
                .ReadFromJsonAsync<JiraMyselfResponse>(
                    cancellationToken: cancellationToken);

            if (user is null || string.IsNullOrWhiteSpace(user.AccountId))
            {
                throw new InvalidOperationException(
                    "Could not retrieve the Jira account ID.");
            }

            return user.AccountId;
        }
    } 
}

