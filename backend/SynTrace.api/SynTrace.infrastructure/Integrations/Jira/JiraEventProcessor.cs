using System.Data;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.IntegrationEvents.Jira.Payloads;
using SynTrace.Contracts.Serialization;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

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
        await using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var scope = new JiraProjectionScope(_db, e.CompanyId, e.JiraConnectionId);
        if (!await scope.IsActiveAsync(ct))
            return JiraEventProcessingResult.Ignored;

        if (await _db.ProcessedJiraEvents.IgnoreQueryFilters().AnyAsync(p => p.CompanyId == e.CompanyId
            && p.JiraConnectionId == e.JiraConnectionId && p.EventId == e.EventId, ct))
            return JiraEventProcessingResult.Duplicate;

        _db.ProcessedJiraEvents.Add(new ProcessedJiraEvent
        {
            CompanyId = e.CompanyId,
            JiraConnectionId = e.JiraConnectionId,
            EventId = e.EventId,
            EventType = e.EventType.ToString(),
            ProcessedAt = DateTime.UtcNow
        });

        await ApplyAsync(e, scope, ct);
        await _db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return JiraEventProcessingResult.Processed;
    }

    private async Task ApplyAsync(CanonicalJiraEvent e, JiraProjectionScope scope, CancellationToken ct)
    {
        var fallbackStamp = (e.OccurredAtUtc ?? e.ReceivedAtUtc).UtcDateTime;

        switch (e.EventType)
        {
            case JiraEventType.IssueCreated:
            {
                var p = Read<JiraIssuePayload>(e);
                await UpsertIssueAsync(scope, e.CompanyId, p.IssueId, p.IssueKey, p.ProjectId, p.ProjectKey, p.Summary, p.Status,
                    p.AssigneeAccountId, (p.SourceUpdatedAtUtc?.UtcDateTime) ?? fallbackStamp, ct);
                break;
            }
            case JiraEventType.IssueUpdated:
            {
                // Status / assignee / summary changes all arrive as the resulting issue state, so one upsert covers
                // SYNT-178 (create/update), SYNT-181 (status) and SYNT-182 (assignment). Changes[] is kept for AI/audit.
                var p = Read<JiraIssueUpdatedPayload>(e);
                await UpsertIssueAsync(scope, e.CompanyId, p.IssueId, p.IssueKey, p.ProjectId, p.ProjectKey, p.Summary, p.Status,
                    p.AssigneeAccountId, (p.SourceUpdatedAtUtc?.UtcDateTime) ?? fallbackStamp, ct);
                break;
            }
            case JiraEventType.IssueDeleted:
            {
                var p = Read<JiraIssuePayload>(e);
                await DeleteIssuesAsync(scope, e.CompanyId, p.SubtaskIds.Append(p.IssueId).Distinct().ToList(), fallbackStamp, ct);
                break;
            }
            case JiraEventType.ProjectCreated:
            case JiraEventType.ProjectUpdated:
            case JiraEventType.ProjectRestoredDeleted:
            case JiraEventType.ProjectArchived:
            case JiraEventType.ProjectRestoredArchived:
            {
                var p = ReadProject(e);
                var restore = e.EventType == JiraEventType.ProjectRestoredDeleted;
                if (await scope.ApplyWatermarkAsync(JiraProjectionKind.Project, p.ProjectId, fallbackStamp, false, restore, ct))
                    await UpsertProjectAsync(e.CompanyId, p, ct);
                break;
            }
            case JiraEventType.ProjectDeleted:
            case JiraEventType.ProjectSoftDeleted:
            {
                var p = ReadProject(e);
                if (await scope.ApplyWatermarkAsync(JiraProjectionKind.Project, p.ProjectId, fallbackStamp, true, false, ct))
                    await DeleteProjectAsync(e.CompanyId, p.ProjectId, ct);
                break;
            }
            case JiraEventType.CommentCreated:
            case JiraEventType.CommentUpdated:
            {
                var p = Read<JiraCommentPayload>(e);
                await UpsertCommentAsync(scope, e.CompanyId, p, fallbackStamp, ct);
                break;
            }
            case JiraEventType.CommentDeleted:
            {
                var p = Read<JiraCommentPayload>(e);
                var comments = _db.JiraComments.IgnoreQueryFilters()
                    .Where(c => c.CompanyId == e.CompanyId && c.ExternalId == p.CommentId);
                if (!await comments.AnyAsync(c => c.SourceUpdatedAt > fallbackStamp, ct) &&
                    await scope.ApplyWatermarkAsync(JiraProjectionKind.Comment, p.CommentId, fallbackStamp, true, false, ct))
                    await comments.ExecuteDeleteAsync(ct);
                break;
            }
            case JiraEventType.SprintCreated:
            case JiraEventType.SprintUpdated:
            case JiraEventType.SprintStarted:
            case JiraEventType.SprintClosed:
            {
                var p = Read<JiraSprintPayload>(e);
                if (await scope.ApplyWatermarkAsync(JiraProjectionKind.Sprint, p.SprintId, fallbackStamp, false, false, ct))
                    await UpsertSprintAsync(e.CompanyId, p, ct);
                break;
            }
            case JiraEventType.SprintDeleted:
            {
                var p = Read<JiraSprintPayload>(e);
                if (await scope.ApplyWatermarkAsync(JiraProjectionKind.Sprint, p.SprintId, fallbackStamp, true, false, ct))
                    await _db.JiraSprints.IgnoreQueryFilters()
                        .Where(x => x.CompanyId == e.CompanyId && x.ExternalId == p.SprintId).ExecuteDeleteAsync(ct);
                break;
            }
            default:
                // Versions / worklogs / links / attachments / issue types / users / boards:
                // the contract exists, persistence is not implemented yet. The event is recorded in the ledger only.
                _logger.LogDebug("Jira event type {EventType} has no persistence handler yet.", e.EventType);
                break;
        }
    }

    private async Task UpsertIssueAsync(
        JiraProjectionScope scope, string companyId, string issueId, string key, string? projectId, string? projectKey,
        string? summary, string? status, string? assignee, DateTime stamp, CancellationToken ct)
    {
        if (await scope.IsDeletedAsync(JiraProjectionKind.Issue, issueId, ct))
            return;

        var issue = await _db.JiraIssues.IgnoreQueryFilters().SingleOrDefaultAsync(i => i.CompanyId == companyId && i.ExternalId == issueId, ct);

        if (await scope.IsStaleForProjectAsync(projectId ?? issue?.ProjectExternalId, stamp, ct))
            return;

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

        issue.Summary = summary ?? issue.Summary;
        issue.Status = status ?? issue.Status;
        issue.AssigneeAccountId = assignee;   // null is meaningful here: unassigned

        if (projectId is not null)
            await EnsureProjectAsync(companyId, projectId, projectKey, ct);
    }

    private async Task DeleteIssuesAsync(JiraProjectionScope scope, string companyId, List<string> issueIds,
        DateTime stamp, CancellationToken ct)
    {
        var newerIds = await _db.JiraIssues.IgnoreQueryFilters()
            .Where(i => i.CompanyId == companyId && issueIds.Contains(i.ExternalId) && i.SourceUpdatedAt > stamp)
            .Select(i => i.ExternalId).ToListAsync(ct);
        var deletedIds = new List<string>();
        foreach (var id in issueIds.Except(newerIds))
        {
            if (await scope.ApplyWatermarkAsync(JiraProjectionKind.Issue, id, stamp, true, false, ct))
                deletedIds.Add(id);
        }

        if (deletedIds.Count == 0) return;
        await _db.JiraComments.IgnoreQueryFilters().Where(c => c.CompanyId == companyId && deletedIds.Contains(c.IssueExternalId))
            .ExecuteDeleteAsync(ct);
        await _db.JiraIssues.IgnoreQueryFilters().Where(i => i.CompanyId == companyId && deletedIds.Contains(i.ExternalId))
            .ExecuteDeleteAsync(ct);
    }

    /// <summary>Jira sends no issue_deleted for the issues of a deleted project.</summary>
    private async Task DeleteProjectAsync(string companyId, string projectId, CancellationToken ct)
    {
        var issueIds = _db.JiraIssues.IgnoreQueryFilters()
            .Where(i => i.CompanyId == companyId && i.ProjectExternalId == projectId)
            .Select(i => i.ExternalId);
        await _db.JiraComments.IgnoreQueryFilters().Where(c => c.CompanyId == companyId && issueIds.Contains(c.IssueExternalId))
            .ExecuteDeleteAsync(ct);
        await _db.JiraIssues.IgnoreQueryFilters().Where(i => i.CompanyId == companyId && i.ProjectExternalId == projectId)
            .ExecuteDeleteAsync(ct);
        var jiraProjects = _db.JiraProjects.IgnoreQueryFilters().Where(p => p.CompanyId == companyId && p.ExternalId == projectId);
        await _db.Projects.IgnoreQueryFilters().Where(p => p.CompanyId == companyId &&
                jiraProjects.Any(j => j.Id == p.JiraProjectId))
            .ExecuteUpdateAsync(setters => setters.SetProperty(p => p.JiraProjectId, (string?)null), ct);
        await jiraProjects.ExecuteDeleteAsync(ct);
    }

    private async Task UpsertProjectAsync(string companyId, JiraProjectPayload payload, CancellationToken ct)
    {
        var project = await _db.JiraProjects.IgnoreQueryFilters()
            .SingleOrDefaultAsync(x => x.CompanyId == companyId && x.ExternalId == payload.ProjectId, ct);
        if (project is null)
        {
            project = new JiraProject { CompanyId = companyId, ExternalId = payload.ProjectId };
            _db.JiraProjects.Add(project);
        }

        project.Key = payload.ProjectKey ?? project.Key;
        project.Name = payload.Name ?? project.Name;
        project.ProjectTypeKey = payload.ProjectTypeKey ?? project.ProjectTypeKey;
        project.LeadAccountId = payload.LeadAccountId ?? project.LeadAccountId;
        project.UpdatedAt = DateTime.UtcNow;
    }

    private async Task EnsureProjectAsync(string companyId, string projectId, string? projectKey, CancellationToken ct)
    {
        var tracked = _db.JiraProjects.Local.Any(p => p.CompanyId == companyId && p.ExternalId == projectId);
        if (tracked || await _db.JiraProjects.IgnoreQueryFilters().AnyAsync(p => p.CompanyId == companyId && p.ExternalId == projectId, ct))
            return;

        _db.JiraProjects.Add(new JiraProject { CompanyId = companyId, ExternalId = projectId, Key = projectKey });
    }

    private async Task UpsertCommentAsync(JiraProjectionScope scope, string companyId, JiraCommentPayload p, DateTime fallbackStamp, CancellationToken ct)
    {
        var stamp = (p.UpdatedAtUtc ?? p.CreatedAtUtc)?.UtcDateTime ?? fallbackStamp;
        if (await scope.IsDeletedAsync(JiraProjectionKind.Comment, p.CommentId, ct) ||
            await scope.IsDeletedAsync(JiraProjectionKind.Issue, p.IssueId, ct))
            return;

        var parentProjectId = p.ProjectId ?? await _db.JiraIssues.IgnoreQueryFilters()
            .Where(x => x.CompanyId == companyId && x.ExternalId == p.IssueId)
            .Select(x => x.ProjectExternalId).SingleOrDefaultAsync(ct);
        if (await scope.IsStaleForProjectAsync(parentProjectId, stamp, ct))
            return;

        var comment = await _db.JiraComments.IgnoreQueryFilters().SingleOrDefaultAsync(c => c.CompanyId == companyId && c.ExternalId == p.CommentId, ct);

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

        comment.BodyText = p.BodyText ?? comment.BodyText;
    }

    private async Task UpsertSprintAsync(string companyId, JiraSprintPayload p, CancellationToken ct)
    {
        var sprint = await _db.JiraSprints.IgnoreQueryFilters().SingleOrDefaultAsync(s => s.CompanyId == companyId && s.ExternalId == p.SprintId, ct);
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
        sprint.UpdatedAt = DateTime.UtcNow;
    }

    private static JiraProjectPayload ReadProject(CanonicalJiraEvent e)
    {
        var payload = Read<JiraProjectPayload>(e);
        if (!string.IsNullOrEmpty(payload.ProjectId))
            return payload;

        // Older workers queued project create/update events with an empty typed payload.
        if (e.RawWebhook is { } raw && JiraWebhookNormalizer.BuildProject(raw) is { } fromWebhook)
            return fromWebhook;

        throw new JsonException("The Jira project payload is missing its project ID.");
    }

    private static T Read<T>(CanonicalJiraEvent e) where T : class =>
        e.Payload.Deserialize<T>(JiraEventContractJson.Options)
        ?? throw new JsonException($"Payload for {e.EventType} could not be deserialized as {typeof(T).Name}.");

}
