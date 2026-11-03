namespace SynTrace.Application.Contracts.Assistant;

public sealed record AssistantLink(string Key, string Url);

public sealed record AssistantAnswer(string Status, string Answer, IReadOnlyList<AssistantLink> Links, string CorrelationId);

public enum AssistantFailure { None, BadRequest, Misconfigured, Unavailable }

public sealed record AssistantResult(AssistantAnswer? Answer, AssistantFailure Failure);

public interface IAssistantClient
{
    Task<AssistantResult> AskAsync(
        string question,
        string companyId,
        string employeeId,
        IReadOnlyList<string> allowedProjects,
        string correlationId,
        CancellationToken cancellationToken);
}
