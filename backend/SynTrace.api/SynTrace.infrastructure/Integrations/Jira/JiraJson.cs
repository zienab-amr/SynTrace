using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace SynTrace.Infrastructure.Integrations.Jira;

internal static class JiraJson
{
    private static readonly Regex OffsetWithoutColon = new(@"^(.*[+-]\d{2})(\d{2})$", RegexOptions.Compiled);

    public static JsonElement? Obj(this JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Object
            ? v : null;

    public static JsonElement? Arr(this JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Array
            ? v : null;

    public static string? Str(this JsonElement e, string name)
    {
        if (e.ValueKind != JsonValueKind.Object || !e.TryGetProperty(name, out var v)) return null;
        return v.ValueKind switch
        {
            JsonValueKind.String => v.GetString(),
            JsonValueKind.Number => v.GetRawText(),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            _ => null
        };
    }

    public static long? Long(this JsonElement e, string name)
    {
        if (e.ValueKind != JsonValueKind.Object || !e.TryGetProperty(name, out var v)) return null;
        if (v.ValueKind == JsonValueKind.Number && v.TryGetInt64(out var n)) return n;
        if (v.ValueKind == JsonValueKind.String && long.TryParse(v.GetString(), out var s)) return s;
        return null;
    }

    public static bool? Bool(this JsonElement e, string name)
    {
        if (e.ValueKind != JsonValueKind.Object || !e.TryGetProperty(name, out var v)) return null;
        return v.ValueKind switch { JsonValueKind.True => true, JsonValueKind.False => false, _ => null };
    }

    public static DateTimeOffset? Date(this JsonElement e, string name) => ParseDate(e.Str(name));

    /// <summary>Jira sends "2024-05-01T10:00:00.000+0000" (offset without colon) - normalise then parse.</summary>
    public static DateTimeOffset? ParseDate(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var m = OffsetWithoutColon.Match(value);
        if (m.Success) value = $"{m.Groups[1].Value}:{m.Groups[2].Value}";
        return DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var d)
            ? d : null;
    }

    /// <summary>Flattens Atlassian Document Format (or a plain string) to text.</summary>
    public static string AdfToText(JsonElement body)
    {
        var sb = new StringBuilder();
        Walk(body, sb);
        return sb.ToString().Trim();
    }

    private static void Walk(JsonElement el, StringBuilder sb)
    {
        switch (el.ValueKind)
        {
            case JsonValueKind.String:
                sb.Append(el.GetString());
                break;
            case JsonValueKind.Object:
                var type = el.Str("type");
                if (el.TryGetProperty("text", out var t) && t.ValueKind == JsonValueKind.String)
                    sb.Append(t.GetString());
                else if (type == "hardBreak")
                    sb.Append('\n');

                if (el.TryGetProperty("content", out var c) && c.ValueKind == JsonValueKind.Array)
                {
                    foreach (var child in c.EnumerateArray()) Walk(child, sb);
                    if (type is "paragraph" or "heading" or "listItem" or "codeBlock")
                        sb.Append('\n');
                }
                break;
        }
    }
}
