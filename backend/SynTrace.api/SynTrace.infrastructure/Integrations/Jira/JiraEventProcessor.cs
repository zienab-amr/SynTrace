using System.Text.Json;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.IntegrationEvents.Jira.Payloads;
using SynTrace.Contracts.Serialization;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

/// <summary>
/// Applies one canonical event to the database inside ONE transaction:
///   1) idempotency ledger insert  2) entity upsert  3) commit.
/// If anything fails the whole transaction rolls back, so the retry starts clean (SYNT-147/151/177..182).
/// Stale / out-of-order events are ignored using the Jira "updated" stamp.
/// </summary>
public sealed class JiraEventProcessor : IJiraEventProcessor
{
    private readonly SynTraceDbContext _db;
    private readonly ILogger<JiraEventProcessor> _logger;

    public JiraEventProcessor(SynTraceDbContext db, ILogger<JiraEventProcessor> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<JiraEventProcessingResult> ProcessAsync(CanonicalJiraEvent e, CancellationToken ct)
    {
        await using var tx = await _db.Database.BeginTransactionAsync(ct);

        // 1) Idempotency
        if (await _db.ProcessedJiraEvents.AnyAsync(p => p.JiraConnectionId == e.JiraConnectionId && p.EventId == e.EventId, ct))
            return JiraEventProcessingResult.Duplicate;

        _db.ProcessedJiraEvents.Add(new ProcessedJiraEvent
        {
            CompanyId = e.CompanyId,
            JiraConnectionId = e.JiraConnectionId,
            EventId = e.EventId,
            EventType = e.EventType.ToString(),
            ProcessedAt = DateTime.UtcNow
        });

        // 2) Apply
        await ApplyAsync(e, ct);

        try
        {
            await _db.SaveChangesAsync(ct);   // unique index (JiraConnectionId, EventId) is the final guard against races
        }
        catch (DbUpdateException ex) when (IsUniqueViolation(ex))
        {
            _logger.LogInformation("Jira event {EventId} was processed concurrently; treating as duplicate.", e.EventId);
            return JiraEventProcessingResult.Duplicate;
        }

        await tx.CommitAsync(ct);
        return JiraEventProcessingResult.Processed;
    }

    private async Task ApplyAsync(CanonicalJiraEvent e, CancellationToken ct)
    {
        var fallbackStamp = (e.OccurredAtUtc ?? e.ReceivedAtUtc).UtcDateTime;

        switch (e.EventType)
        {
            case JiraEventType.IssueCreated:
            {
                var p = Read<JiraIssuePayload>(e);
                await UpsertIssueAsync(e.CompanyId, p.IssueId, p.IssueKey, p.ProjectId, p.ProjectKey, p.Summary, p.Status,
                    p.AssigneeAccountId, (p.SourceUpdatedAtUtc?.UtcDateTime) ?? fallbackStamp, isDelete: false, ct);
                break;
            }
            case JiraEventType.IssueUpdated:
            {
                // Status / assignee / summary changes all arrive as the resulting issue state, so one upsert covers
                // SYNT-178 (create/update), SYNT-181 (status) and SYNT-182 (assignment). Changes[] is kept for AI/audit.
                var p = Read<JiraIssueUpdatedPayload>(e);
                await UpsertIssueAsync(e.CompanyId, p.IssueId, p.IssueKey, p.ProjectId, p.ProjectKey, p.Summary, p.Status,
                    p.AssigneeAccountId, (p.SourceUpdatedAtUtc?.UtcDateTime) ?? fallbackStamp, isDelete: false, ct);
                break;
            }
            case JiraEventType.IssueDeleted:
            {
                var p = Read<JiraIssuePayload>(e);
                await UpsertIssueAsync(e.CompanyId, p.IssueId, p.IssueKey, p.ProjectId, p.ProjectKey, null, null,
                    null, fallbackStamp, isDelete: true, ct);
                break;
            }
            case JiraEventType.CommentCreated:
            case JiraEventType.CommentUpdated:
            case JiraEventType.CommentDeleted:
            {
                var p = Read<JiraCommentPayload>(e);
                await UpsertCommentAsync(e.CompanyId, p, fallbackStamp, e.EventType == JiraEventType.CommentDeleted, ct);
                break;
            }
            case JiraEventType.SprintCreated:
            case JiraEventType.SprintUpdated:
            case JiraEventType.SprintStarted:
            case JiraEventType.SprintClosed:
            case JiraEventType.SprintDeleted:
            {
                var p = Read<JiraSprintPayload>(e);
                await UpsertSprintAsync(e.CompanyId, p, e.EventType == JiraEventType.SprintDeleted, ct);
                break;
            }
            default:
                // Versions / worklogs / links / issue types / projects / users / boards:
                // the contract exists, persistence is not implemented yet. The event is recorded in the ledger only.
                _logger.LogDebug("Jira event type {EventType} has no persistence handler yet.", e.EventType);
                break;
        }
    }

    private async Task UpsertIssueAsync(
        string companyId, string issueId, string key, string? projectId, string? projectKey,
        string? summary, string? status, string? assignee, DateTime stamp, bool isDelete, CancellationToken ct)
    {
        var issue = await _db.JiraIssues.SingleOrDefaultAsync(i => i.CompanyId == companyId && i.ExternalId == issueId, ct);

        if (issue is null)
        {
            issue = new JiraIssue { CompanyId = companyId, ExternalId = issueId, CreatedAt = DateTime.UtcNow };
            _db.JiraIssues.Add(issue);
        }
        else if (issue.SourceUpdatedAt is { } existing && stamp < existing)
        {
            _logger.LogInformation("Ignoring stale event for issue {IssueKey} ({Incoming:o} < {Existing:o}).", key, stamp, existing);
            return;
        }

        issue.Key = key;
        issue.ProjectExternalId = projectId ?? issue.ProjectExternalId;
        issue.ProjectKey = projectKey ?? issue.ProjectKey;
        issue.SourceUpdatedAt = stamp;
        issue.UpdatedAt = DateTime.UtcNow;

        if (isDelete)
        {
            issue.IsDeleted = true;     // soft delete + tombstone so a late, older "created" cannot resurrect it
        }
        else
        {
            issue.IsDeleted = false;
            issue.Summary = summary ?? issue.Summary;
            issue.Status = status ?? issue.Status;
            issue.AssigneeAccountId = assignee;   // null is meaningful here: unassigned
        }

        if (projectId is not null)
            await EnsureProjectAsync(companyId, projectId, projectKey, ct);
    }

    private async Task EnsureProjectAsync(string companyId, string projectId, string? projectKey, CancellationToken ct)
    {
        var tracked = _db.JiraProjects.Local.Any(p => p.CompanyId == companyId && p.ExternalId == projectId);
        if (tracked || await _db.JiraProjects.AnyAsync(p => p.CompanyId == companyId && p.ExternalId == projectId, ct))
            return;

        _db.JiraProjects.Add(new JiraProject { CompanyId = companyId, ExternalId = projectId, Key = projectKey });
    }

    private async Task UpsertCommentAsync(string companyId, JiraCommentPayload p, DateTime fallbackStamp, bool isDelete, CancellationToken ct)
    {
        var stamp = (p.UpdatedAtUtc ?? p.CreatedAtUtc)?.UtcDateTime ?? fallbackStamp;
        var comment = await _db.JiraComments.SingleOrDefaultAsync(c => c.CompanyId == companyId && c.ExternalId == p.CommentId, ct);

        if (comment is null)
        {
            comment = new JiraComment { CompanyId = companyId, ExternalId = p.CommentId, CreatedAt = DateTime.UtcNow };
            _db.JiraComments.Add(comment);
        }
        else if (comment.SourceUpdatedAt is { } existing && stamp < existing)
        {
            return;
        }

        comment.IssueExternalId = p.IssueId;
        comment.IssueKey = p.IssueKey ?? comment.IssueKey;
        comment.AuthorAccountId = p.AuthorAccountId ?? comment.AuthorAccountId;
        comment.SourceCreatedAt = p.CreatedAtUtc?.UtcDateTime ?? comment.SourceCreatedAt;
        comment.SourceUpdatedAt = stamp;
        comment.UpdatedAt = DateTime.UtcNow;

        if (isDelete)
        {
            comment.IsDeleted = true;
        }
        else
        {
            comment.IsDeleted = false;
            comment.BodyText = p.BodyText ?? comment.BodyText;
        }
    }

    private async Task UpsertSprintAsync(string companyId, JiraSprintPayload p, bool isDelete, CancellationToken ct)
    {
        var sprint = await _db.JiraSprints.SingleOrDefaultAsync(s => s.CompanyId == companyId && s.ExternalId == p.SprintId, ct);
        if (sprint is null)
        {
            sprint = new JiraSprint { CompanyId = companyId, ExternalId = p.SprintId, CreatedAt = DateTime.UtcNow };
            _db.JiraSprints.Add(sprint);
        }

        sprint.Name = p.Name ?? sprint.Name;
        sprint.State = p.State ?? sprint.State;
        sprint.BoardExternalId = p.BoardId ?? sprint.BoardExternalId;
        sprint.StartDate = p.StartDateUtc?.UtcDateTime ?? sprint.StartDate;
        sprint.EndDate = p.EndDateUtc?.UtcDateTime ?? sprint.EndDate;
        sprint.CompleteDate = p.CompleteDateUtc?.UtcDateTime ?? sprint.CompleteDate;
        sprint.IsDeleted = isDelete;
        sprint.UpdatedAt = DateTime.UtcNow;
    }

    private static T Read<T>(CanonicalJiraEvent e) where T : class =>
        e.Payload.Deserialize<T>(JiraEventContractJson.Options)
        ?? throw new JsonException($"Payload for {e.EventType} could not be deserialized as {typeof(T).Name}.");

    private static bool IsUniqueViolation(DbUpdateException ex) =>
        ex.GetBaseException() is SqlException { Number: 2601 or 2627 };
}
