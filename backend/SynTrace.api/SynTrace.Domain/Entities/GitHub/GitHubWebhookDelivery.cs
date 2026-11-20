namespace SynTrace.Domain.Entities.GitHub;

public sealed class GitHubWebhookDelivery
{
    public Guid Id { get; set; }
    public required string CompanyId { get; set; }
    public long InstallationId { get; set; }
    public long? RepositoryId { get; set; }
    public string? BindingId { get; set; }
    public required string EventName { get; set; }
    public string? Action { get; set; }
    public DateTime ReceivedAtUtc { get; set; }
    public DateTime NextDispatchAtUtc { get; set; }
    public DateTime? LastPublishedAtUtc { get; set; }
    public Guid? DispatchLeaseId { get; set; }
    public DateTime? DispatchLeaseUntilUtc { get; set; }
    public Guid? ProcessingLeaseId { get; set; }
    public DateTime? ProcessingLeaseUntilUtc { get; set; }
    public DateTime? ProcessingNotBeforeUtc { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public DateTime? DeadLetteredAtUtc { get; set; }
    public int ProcessingAttempts { get; set; }
    public bool SendToDeadLetter { get; set; }
    public string? LastFailureType { get; set; }
}
