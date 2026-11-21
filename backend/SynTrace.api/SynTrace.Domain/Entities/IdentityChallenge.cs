namespace SynTrace.Domain.Entities;

public sealed class IdentityChallenge
{
    public string Key { get; set; } = string.Empty;
    public string? SubjectId { get; set; }
    public string? ProtectedCode { get; set; }
    public string? ProofHash { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime SendWindowUtc { get; set; }
    public int SendsInWindow { get; set; }
    public int Attempts { get; set; }
}
