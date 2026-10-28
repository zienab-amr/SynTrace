using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json.Serialization;

namespace SynTrace.Application.DTOs.Requests
{
    public sealed class JiraOAuthTokenRequest
    {
        [JsonPropertyName("grant_type")]
        public string GrantType { get; set; } = string.Empty;

        [JsonPropertyName("client_id")]
        public string ClientId { get; set; } = string.Empty;

        [JsonPropertyName("client_secret")]
        public string ClientSecret { get; set; } = string.Empty;

        [JsonPropertyName("code")]
        public string Code { get; set; } = string.Empty;

        [JsonPropertyName("redirect_uri")]
        public string RedirectUri { get; set; } = string.Empty;
    }
}
