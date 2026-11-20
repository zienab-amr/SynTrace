using System.Text.Json;
using System.Text.Json.Serialization;

namespace SynTrace.Contracts.Serialization;

/// <summary>Single source of truth for contract JSON settings in all .NET services.</summary>
public static class JiraEventContractJson
{
    public static JsonSerializerOptions Options { get; } = CreateOptions();

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web)
        {
            PropertyNameCaseInsensitive = true,
            WriteIndented = false
        };

        // Enum values remain explicit strings such as "IssueUpdated", never integers.
        options.Converters.Add(new JsonStringEnumConverter(namingPolicy: null, allowIntegerValues: false));
        return options;
    }
}
