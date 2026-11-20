using SynTrace.Contracts.IntegrationEvents.Jira;

namespace SynTrace.Contracts.Validation;

/// <summary>
/// Validates envelope-level invariants only. Event-specific Payload schema validation
/// belongs at the normalization/consumer boundary and must be tested per event family.
/// </summary>
public static class CanonicalJiraEventValidator
{
    public static IReadOnlyList<string> Validate(CanonicalJiraEvent? value)
    {
        var errors = new List<string>();
        if (value is null)
        {
            errors.Add("Event is required.");
            return errors;
        }

        if (string.IsNullOrWhiteSpace(value.EventId))
            errors.Add("EventId is required.");

        if (!Enum.IsDefined(value.EventType))
            errors.Add("EventType must be a supported JiraEventType value.");

        if (value.SchemaVersion < 1)
            errors.Add("SchemaVersion must be greater than or equal to 1.");

        if (string.IsNullOrWhiteSpace(value.SourceEventName))
            errors.Add("SourceEventName is required.");

        if (string.IsNullOrWhiteSpace(value.CompanyId))
            errors.Add("CompanyId is required.");

        if (string.IsNullOrWhiteSpace(value.JiraConnectionId))
            errors.Add("JiraConnectionId is required.");

        if (value.ReceivedAtUtc == default)
            errors.Add("ReceivedAtUtc is required.");

        if (value.Payload.ValueKind != System.Text.Json.JsonValueKind.Object)
            errors.Add("Payload must be a JSON object.");

        return errors;
    }
}
