namespace SynTrace.Application.Contracts.Assistant;

/// <summary>Returns project scope + authenticated Jira identity; never accepts IDs from Flutter.</summary>
public sealed record AssistantAccessContext(
    AssistantProjectScope Scope, string? JiraAccountId, bool HasAccessibleProjects);

public interface IAssistantAccessContextProvider
{
    Task<AssistantAccessContext> GetForCurrentEmployeeAsync(
        string companyId, string employeeId, CancellationToken cancellationToken);
}
