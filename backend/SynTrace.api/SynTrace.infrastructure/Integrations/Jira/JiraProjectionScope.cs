using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

internal sealed class JiraProjectionScope(SynTraceDbContext db, string companyId, string connectionId)
{
    public Task<bool> IsActiveAsync(CancellationToken ct) =>
        db.JiraConnections.AnyAsync(x => x.Id == connectionId && x.CompanyId == companyId && x.status
            && x.JiraConnectionType == JiraConnectionType.Company, ct);

    public async Task RequireActiveAsync(CancellationToken ct)
    {
        if (!await IsActiveAsync(ct))
            throw new InvalidOperationException("The Jira company connection is no longer active.");
    }

    private IQueryable<JiraProjectionWatermark> Watermarks(JiraProjectionKind kind) =>
        db.Set<JiraProjectionWatermark>().Where(x => x.JiraConnectionId == connectionId
            && x.CompanyId == companyId && x.Kind == kind);

    public Task<bool> IsDeletedAsync(JiraProjectionKind kind, string? externalId, CancellationToken ct) =>
        string.IsNullOrEmpty(externalId) ? Task.FromResult(false) :
            Watermarks(kind).AnyAsync(x => x.ExternalId == externalId && x.IsDeleted, ct);

    public Task<bool> IsStaleForProjectAsync(string? externalId, DateTime stamp, CancellationToken ct) =>
        string.IsNullOrEmpty(externalId) ? Task.FromResult(false) :
            Watermarks(JiraProjectionKind.Project).AnyAsync(x => x.ExternalId == externalId &&
                (x.IsDeleted || x.LastDeletedAtUtc >= stamp), ct);

    public async Task<HashSet<string>> BlockedSnapshotIdsAsync(JiraProjectionKind kind,
        IReadOnlyCollection<string> ids, DateTime observedAt, CancellationToken ct)
    {
        if (ids.Count == 0) return new HashSet<string>(StringComparer.Ordinal);
        var result = await Watermarks(kind).Where(x => ids.Contains(x.ExternalId) &&
                (x.IsDeleted || ((kind == JiraProjectionKind.Project || kind == JiraProjectionKind.Sprint) && x.SourceOccurredAtUtc >= observedAt)))
            .Select(x => x.ExternalId).ToListAsync(ct);
        return new HashSet<string>(result, StringComparer.Ordinal);
    }

    public async Task<bool> ApplyWatermarkAsync(JiraProjectionKind kind, string externalId, DateTime stamp,
        bool delete, bool allowRestore, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(externalId) || externalId.Length > 64)
            throw new System.Text.Json.JsonException("The Jira entity ID is invalid.");

        var watermark = await Watermarks(kind).SingleOrDefaultAsync(x => x.ExternalId == externalId, ct);
        if (watermark is not null)
        {
            if (stamp < watermark.SourceOccurredAtUtc ||
                (watermark.IsDeleted && !delete && (!allowRestore || stamp <= watermark.SourceOccurredAtUtc)))
                return false;
        }
        else
        {
            watermark = new JiraProjectionWatermark
            {
                CompanyId = companyId, JiraConnectionId = connectionId, Kind = kind, ExternalId = externalId
            };
            db.Add(watermark);
        }
        watermark.IsDeleted = delete;
        if (delete) watermark.LastDeletedAtUtc = stamp;
        watermark.SourceOccurredAtUtc = stamp;
        return true;
    }
}
