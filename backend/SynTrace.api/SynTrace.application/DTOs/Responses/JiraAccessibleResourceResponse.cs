using System.Text.Json.Serialization;

namespace SynTrace.Application.DTOs.Responses;

public class JiraAccessibleResourceResponse
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("scopes")]
    public List<string> Scopes { get; set; } = [];

    [JsonPropertyName("avatarUrl")]
    public string? AvatarUrl { get; set; }
}