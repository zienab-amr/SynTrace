using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities.GitHub;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Realtime;

[Authorize]
public sealed class ProjectStatusHub(ProjectStatusSubscriptions subscriptions, ProjectIntegrationAccess access) : Hub
{
    public const string Path = "/hubs/project-status";

    public async Task WatchProject(string projectId)
    {
        var company = Context.User?.FindFirstValue("CompanyId");
        var employee = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (company is null || employee is null || string.IsNullOrWhiteSpace(projectId) || projectId.Length > 450
            || await access.ReadProjectAsync(company, employee, projectId, Context.ConnectionAborted) is null)
            throw new HubException("Project is unavailable.");

        if (!subscriptions.TryWatch(Context.ConnectionId, company, employee, projectId))
            throw new HubException("Project subscription limit reached.");
    }

    public void UnwatchProject(string projectId) => subscriptions.Remove(Context.ConnectionId, projectId);

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        subscriptions.RemoveConnection(Context.ConnectionId);
        return base.OnDisconnectedAsync(exception);
    }
}

public sealed class ProjectStatusSubscriptions
{
    private readonly Dictionary<(string Connection, string Project), Watch> _entries = [];
    private readonly object _lock = new();

    public bool TryWatch(string connection, string company, string employee, string project)
    {
        lock (_lock)
        {
            var key = (connection, project);
            if (_entries.ContainsKey(key))
                return true;
            if (_entries.Count >= 500 || _entries.Keys.Count(x => x.Connection == connection) >= 5)
                return false;
            _entries[key] = new Watch(connection, company, employee, project);
            return true;
        }
    }

    public Watch[] Snapshot()
    {
        lock (_lock) return [.. _entries.Values];
    }

    public bool IsCurrent(Watch watch)
    {
        lock (_lock) return _entries.TryGetValue((watch.Connection, watch.Project), out var current)
            && ReferenceEquals(current, watch);
    }

    public void Remove(string connection, string project)
    {
        lock (_lock) _entries.Remove((connection, project));
    }

    public void RemoveConnection(string connection)
    {
        lock (_lock)
            foreach (var key in _entries.Keys.Where(x => x.Connection == connection).ToArray())
                _entries.Remove(key);
    }

    public sealed class Watch(string connection, string company, string employee, string project)
    {
        public string Connection { get; } = connection;
        public string Company { get; } = company;
        public string Employee { get; } = employee;
        public string Project { get; } = project;
        public ProjectStatusNotice? Last { get; set; }
    }
}

public sealed record ProjectStatusNotice(string ProjectId, string State, long? RequestedVersion,
    long? CompletedVersion, DateTime? LastSuccessAtUtc);

public sealed class ProjectStatusNotifier(ProjectStatusSubscriptions subscriptions,
    IServiceScopeFactory scopes, IHubContext<ProjectStatusHub> hub, ILogger<ProjectStatusNotifier> logger)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(5));
        while (await timer.WaitForNextTickAsync(ct))
        {
            foreach (var watch in subscriptions.Snapshot())
            {
                try
                {
                    await PublishAsync(watch, ct);
                }
                catch (Exception error) when (!ct.IsCancellationRequested)
                {
                    logger.LogWarning("Project status notification failed ({ErrorType}).", error.GetType().Name);
                }
            }
        }
    }

    private async Task PublishAsync(ProjectStatusSubscriptions.Watch watch, CancellationToken ct)
    {
        await using var scope = scopes.CreateAsyncScope();
        var access = scope.ServiceProvider.GetRequiredService<ProjectIntegrationAccess>();
        if (await access.ReadProjectAsync(watch.Company, watch.Employee, watch.Project, ct) is null)
        {
            if (subscriptions.IsCurrent(watch))
                subscriptions.Remove(watch.Connection, watch.Project);
            return;
        }

        var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
        var sync = await (from binding in db.Set<GitHubRepositoryBinding>().AsNoTracking()
            join connection in db.Set<GitHubConnection>() on binding.CompanyId equals connection.CompanyId
            join job in db.Set<GitHubRepositorySync>() on binding.Id equals job.BindingId
            where binding.CompanyId == watch.Company && binding.ProjectId == watch.Project && binding.IsActive
                && connection.InstallationId == binding.InstallationId && connection.IsActive && !connection.IsSuspended
                && !job.Revoked
            select new { job.LastFailure, job.RequestedVersion, job.CompletedVersion, job.LastSuccessAtUtc })
            .SingleOrDefaultAsync(ct);
        var state = sync is null ? "not-mapped"
            : sync.LastFailure is not null ? "retrying"
            : sync.RequestedVersion > sync.CompletedVersion ? "pending" : "synced";
        var notice = new ProjectStatusNotice(watch.Project, state, sync?.RequestedVersion,
            sync?.CompletedVersion, sync?.LastSuccessAtUtc);
        if (notice == watch.Last || !subscriptions.IsCurrent(watch))
            return;
        await hub.Clients.Client(watch.Connection).SendAsync("ProjectStatusChanged", notice, ct);
        watch.Last = notice;
    }
}
