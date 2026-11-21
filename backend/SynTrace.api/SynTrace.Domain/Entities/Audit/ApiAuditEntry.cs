namespace SynTrace.Domain.Entities.Audit;

public sealed class ApiAuditEntry
{
    public long Id { get; set; }
    public required string CompanyId { get; set; }
    public required string EmployeeId { get; set; }
    public required string Operation { get; set; }
    public int StatusCode { get; set; }
    public DateTimeOffset OccurredAtUtc { get; set; }
}
