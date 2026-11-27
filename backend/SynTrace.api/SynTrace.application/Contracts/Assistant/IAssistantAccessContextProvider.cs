namespace SynTrace.Application.Contracts.Assistant;

/// <summary>Returns project scope + authenticated Jira identity; never accepts IDs from Flutter.</summary>
public sealed record AssistantAccessContext(
    AssistantProjectScope Scope, string? JiraAccountId, bool HasAccessibleProjects)
{
    public int HistoryCount { get; init; } = 3;
}

public interface IAssistantAccessContextProvider
{
    Task<AssistantAccessContext> GetForCurrentEmployeeAsync(
        string companyId, string employeeId, CancellationToken cancellationToken);
}
