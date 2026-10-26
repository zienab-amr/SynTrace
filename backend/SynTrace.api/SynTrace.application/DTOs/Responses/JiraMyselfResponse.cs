using System.Text.Json.Serialization;

namespace SynTrace.Application.DTOs.Responses;

public class JiraMyselfResponse
{
    [JsonPropertyName("accountId")]
    public string AccountId { get; set; } = string.Empty;
}