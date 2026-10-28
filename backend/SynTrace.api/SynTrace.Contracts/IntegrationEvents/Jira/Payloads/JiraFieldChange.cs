namespace SynTrace.Contracts.IntegrationEvents.Jira.Payloads;

/// <summary>One field change normalized from Jira's changelog.</summary>
public sealed record JiraFieldChange(
    string Field,
    string? From,
    string? To);
