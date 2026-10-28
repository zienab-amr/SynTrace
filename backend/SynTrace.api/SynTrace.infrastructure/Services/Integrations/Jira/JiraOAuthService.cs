using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Integrations.Jira;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.Options;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Enums;
using Microsoft.Extensions.Caching.Memory;

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
        private readonly IMemoryCache _memoryCache;
        private const int PendingConnectionMinutes = 5;

        public JiraOAuthService(
            IOptions<JiraOAuthOptions> options,
            IHttpClientFactory httpClientFactory,
            ICurrentTenant currentTenant,
            ICurrentEmployee currentEmployee,
            IJiraOAuthConnectionRepository jiraOAuthConnectionRepository,
            IDataProtectionProvider dataProtectionProvider,
            IMemoryCache memoryCache
            )
        {
            _options = options;
            _httpClientFactory = httpClientFactory;
            _currentTenant = currentTenant;
            _currentEmployee = currentEmployee;
            _jiraOAuthConnectionRepository = jiraOAuthConnectionRepository;
            _tokenProtector = dataProtectionProvider.CreateProtector("SynTrace.Integrations.Jira.Tokens.v1");
            _memoryCache = memoryCache;
        }

        public async Task<string> ConnectJira()
        {
            var companyId = _currentTenant.CompanyId;
            var checkExistingConnection = await _jiraOAuthConnectionRepository.CheckConnection(companyId);
            if(checkExistingConnection)
            {
                throw new CompanyJiraConnectionAlreadyExistsException("A Jira connection already exists for this company.");
            }

            var (stateHash, authorizationUrl) = CreateAuthorizationUrl();

            var newState = new JiraOAuthState
            {
                JiraOAuthStateId = Guid.NewGuid().ToString(),
                StateHash = stateHash,
                ConnectionType = Domain.Enums.JiraConnectionType.Company,
                EmployeeId = _currentEmployee.EmployeeId,
                CompanyId = companyId,
                ExpiresAt = DateTime.UtcNow.AddMinutes(5),
                ConsumedAt = null
            };
            await _jiraOAuthConnectionRepository.CreateState(newState);

            return authorizationUrl;
        }

        public async Task<JiraOAuthCallbackResponse> CallBack(
    string code,
    string state,
    CancellationToken cancellationToken)
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

            var token = await ExchangeCodeForTokenAsync(
                code, cancellationToken);

            var resources = await GetAccessibleResourcesAsync(
                token.AccessToken, cancellationToken);

            if (resources.Count == 0)
            {
                throw new InvalidOperationException(
                    "No accessible Jira sites were found for this account.");
            }

            var encryptedAccessToken =
                _tokenProtector.Protect(token.AccessToken);

            var encryptedRefreshToken =
                string.IsNullOrWhiteSpace(token.RefreshToken)
                    ? null
                    : _tokenProtector.Protect(token.RefreshToken);

            // Company: wait for the Admin to choose a Site.
            if (oauthState.ConnectionType == JiraConnectionType.Company)
            {
                var pendingId =
                    Convert.ToHexString(RandomNumberGenerator.GetBytes(32));

                var pendingData = new PendingCompanyConnection(
                    oauthState.CompanyId,
                    oauthState.EmployeeId,
                    oauthState.ConnectionType,
                    encryptedAccessToken,
                    encryptedRefreshToken,
                    resources
                );

                _memoryCache.Set(
                    GetPendingCacheKey(pendingId),
                    pendingData,
                    TimeSpan.FromMinutes(PendingConnectionMinutes));

                return new JiraOAuthCallbackResponse(
                    true,
                    pendingId,
                    "Choose the Jira site for your company."
                );
            }

            // Employee: must use the exact CloudId selected by the Admin.
            if (oauthState.ConnectionType == JiraConnectionType.Employee)
            {
                var companyConnection =
                    await _jiraOAuthConnectionRepository.GetActiveCompanyConnection(
                        oauthState.CompanyId);

                if (companyConnection is null)
                {
                    throw new InvalidOperationException(
                        "The company administrator must connect Jira first.");
                }

                var selectedResource = resources.FirstOrDefault(
                    r => r.Id == companyConnection.CloudId);

                if (selectedResource is null)
                {
                    throw new InvalidOperationException(
                        "Your Jira account does not have access to the Jira site selected by your company.");
                }

                var jiraAccountId = await GetJiraAccountIdAsync(
                    selectedResource.Id,
                    token.AccessToken,
                    cancellationToken);

                var employeeConnection = new JiraConnection
                {
                    Id = Guid.NewGuid().ToString(),
                    JiraAccountId = jiraAccountId,
                    CloudId = selectedResource.Id,
                    SiteUrl = selectedResource.Url,
                    EncryptedAccessToken = encryptedAccessToken,
                    EncryptedRefreshToken = encryptedRefreshToken,
                    JiraConnectionType = JiraConnectionType.Employee,
                    ConnectedByEmployeeId = oauthState.EmployeeId,
                    CompanyId = oauthState.CompanyId,
                    status = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                await SaveConnectionAsync(employeeConnection);

                return new JiraOAuthCallbackResponse(
                    false,
                    null,
                    "Employee Jira connection completed."
                );
            }

            throw new InvalidOperationException(
                "Unsupported Jira connection type.");
        }

        public async Task<string> ConnectEmployeeJira()
        {
            var companyId = _currentTenant.CompanyId;
            var employeeId = _currentEmployee.EmployeeId;

            var companyConnection =
                await _jiraOAuthConnectionRepository.GetActiveCompanyConnection(companyId);

            if (companyConnection is null)
            {
                throw new InvalidOperationException(
                    "The company administrator must connect Jira first.");
            }

            // 1. Check whether this employee already has an active Jira connection.
            var checkExistingConnection =
                await _jiraOAuthConnectionRepository.CheckEmployeeConnection(
                    companyId,
                    employeeId);

            if (checkExistingConnection)
            {
                throw new EmployeeJiraConnectionAlreadyExistsException(
                    "A Jira connection already exists for this employee.");
            }

            // 2. Create the authorization URL and state hash.
            var (stateHash, authorizationUrl) = CreateAuthorizationUrl();

            // 3. Save the OAuth state before returning the authorization URL.
            var newState = new JiraOAuthState
            {
                JiraOAuthStateId = Guid.NewGuid().ToString(),
                StateHash = stateHash,
                ConnectionType = JiraConnectionType.Employee,
                EmployeeId = employeeId,
                CompanyId = companyId,
                ExpiresAt = DateTime.UtcNow.AddMinutes(5),
                ConsumedAt = null
            };

            await _jiraOAuthConnectionRepository.CreateState(newState);

            // 4. Return the URL to the caller.
            return authorizationUrl;
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

        public Task<IReadOnlyList<JiraSiteOptionResponse>>
    GetPendingCompanyJiraSites(string pendingId)
        {
            var pending = GetOwnedPendingCompanyConnection(pendingId);

            IReadOnlyList<JiraSiteOptionResponse> sites = pending.Resources
                .GroupBy(r => r.Id)
                .Select(g => g.First())
                .Select(r => new JiraSiteOptionResponse(
                    r.Id,
                    r.Url))
                .ToArray();

            return Task.FromResult(sites);
        }

        public async Task CompleteCompanyJiraConnection(
    string pendingId,
    string cloudId,
    CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(cloudId))
                throw new ArgumentException("CloudId is required.", nameof(cloudId));

            var pending = GetOwnedPendingCompanyConnection(pendingId);

            var selectedResource = pending.Resources.FirstOrDefault(
                r => r.Id == cloudId);

            if (selectedResource is null)
            {
                throw new ArgumentException(
                    "The selected Jira site is not part of the available resources.");
            }

            if (await _jiraOAuthConnectionRepository.CheckConnection(
                pending.CompanyId))
            {
                throw new CompanyJiraConnectionAlreadyExistsException(
                    "A Jira connection already exists for this company.");
            }

            var accessToken =
                _tokenProtector.Unprotect(pending.EncryptedAccessToken);

            var jiraAccountId = await GetJiraAccountIdAsync(
                selectedResource.Id,
                accessToken,
                cancellationToken);

            var companyConnection = new JiraConnection
            {
                Id = Guid.NewGuid().ToString(),
                JiraAccountId = jiraAccountId,
                CloudId = selectedResource.Id,
                SiteUrl = selectedResource.Url,
                EncryptedAccessToken = pending.EncryptedAccessToken,
                EncryptedRefreshToken = pending.EncryptedRefreshToken,
                JiraConnectionType = JiraConnectionType.Company,
                ConnectedByEmployeeId = pending.EmployeeId,
                CompanyId = pending.CompanyId,
                status = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            await SaveConnectionAsync(companyConnection);

            // Remove only after successful persistence.
            _memoryCache.Remove(GetPendingCacheKey(pendingId));
        }

        private async Task SaveConnectionAsync(JiraConnection connection)
        {
            try
            {
                await _jiraOAuthConnectionRepository.CreateConnection(connection);
            }
            catch (DbUpdateException ex)
            {
                var sqlException = ex.GetBaseException() as SqlException;

                var isUniqueViolation =
                    sqlException is not null &&
                    (sqlException.Number == 2601 ||
                     sqlException.Number == 2627);

                if (isUniqueViolation && connection.status)
                {
                    if (connection.JiraConnectionType == JiraConnectionType.Company &&
                        await _jiraOAuthConnectionRepository.CheckConnection(
                            connection.CompanyId))
                    {
                        throw new CompanyJiraConnectionAlreadyExistsException(
                            "A Jira connection already exists for this company.");
                    }

                    if (connection.JiraConnectionType == JiraConnectionType.Employee &&
                        await _jiraOAuthConnectionRepository.CheckEmployeeConnection(
                            connection.CompanyId,
                            connection.ConnectedByEmployeeId))
                    {
                        throw new EmployeeJiraConnectionAlreadyExistsException(
                            "A Jira connection already exists for this employee.");
                    }
                }

                // Preserve database errors unrelated to the expected conflict.
                throw;
            }
        }
        private static string ComputeHash(string data)
        {
            var hash = SHA256.HashData(
                Encoding.UTF8.GetBytes(data));

            return Convert.ToHexString(hash);
        }

        private PendingCompanyConnection GetOwnedPendingCompanyConnection(
    string pendingId)
        {
            if (string.IsNullOrWhiteSpace(pendingId))
                throw new ArgumentException("PendingId is required.", nameof(pendingId));

            if (!_memoryCache.TryGetValue(
                GetPendingCacheKey(pendingId),
                out PendingCompanyConnection? pending) ||
                pending is null)
            {
                throw new InvalidOperationException(
                    "The pending Jira selection has expired or was already completed.");
            }

            if (pending.ConnectionType != JiraConnectionType.Company ||
                pending.CompanyId != _currentTenant.CompanyId ||
                pending.EmployeeId != _currentEmployee.EmployeeId)
            {
                throw new UnauthorizedAccessException(
                    "You are not allowed to complete this Jira connection.");
            }

            return pending;
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

        private async Task<string> GetJiraAccountIdAsync(string cloudId, string accessToken, CancellationToken cancellationToken)
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

        private sealed record PendingCompanyConnection(
            string CompanyId,
            string EmployeeId,
            JiraConnectionType ConnectionType,
            string EncryptedAccessToken,
            string? EncryptedRefreshToken,
            List<JiraAccessibleResourceResponse> Resources
        );

        private static string GetPendingCacheKey(string pendingId) =>
            $"SynTrace:Jira:PendingCompany:{pendingId}";

        private (string stateHash, string authorizationUrl) CreateAuthorizationUrl()
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
            return (stateHash, authorizationUrl);
        }
    } 
}

