using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging.Abstractions;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Application.Exceptions;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Services.Meetings;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Services.Assistant;

internal static class AssistantScopeChecks
{
    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = new SynTraceDbContext(new DbContextOptionsBuilder<SynTraceDbContext>()
            .UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();

        var company = new Company { CompanyId = "a", CompanyName = "Company A" };
        var employee = new Employee { Id = "employee", CompanyId = company.CompanyId, FirstName = "Test", LastName = "Member" };
        var client = new Client { ClientId = "client-a", CompanyId = company.CompanyId, ClientName = "Client A" };
        db.AddRange(company, employee, client);
        db.AddRange(
            new JiraProject { Id = "jira-p1", CompanyId = company.CompanyId, Key = "TEAM", ExternalId = "10001" },
            new JiraProject { Id = "jira-p2", CompanyId = company.CompanyId, Key = "OTHER", ExternalId = "10002" });
        db.AddRange(
            new Project { ProjectId = "p1", CompanyId = company.CompanyId, ClientId = client.ClientId, ProjectName = "Team", JiraProjectId = "jira-p1" },
            new Project { ProjectId = "p2", CompanyId = company.CompanyId, ClientId = client.ClientId, ProjectName = "Other", JiraProjectId = "jira-p2" });
        db.Add(new EmployeeProject { EmployeeId = employee.Id, CompanyId = company.CompanyId, ProjectId = "p1", Role = "Member" });
        var jira = new JiraConnection
        {
            Id = "jira-install", CompanyId = company.CompanyId, ConnectedByEmployeeId = employee.Id,
            JiraConnectionType = JiraConnectionType.Company
        };
        db.Add(jira);
        await db.SaveChangesAsync();

        var assistant = new AssistantProjectAccess(db, new ProjectIntegrationAccess(db));
        var scope = await assistant.GetScopeAsync(company.CompanyId, employee.Id, default);
        if (!scope.JiraKeys.SequenceEqual(new[] { "TEAM" }) || !scope.SynTraceProjectIds.SequenceEqual(new[] { "p1" }))
            throw new InvalidOperationException("Assistant access must follow project membership.");

        await CheckMeetingGatewayAsync(assistant);
        jira.status = false;
        await db.SaveChangesAsync();
        scope = await assistant.GetScopeAsync(company.CompanyId, employee.Id, default);
        if (scope.JiraKeys.Count != 0 || !scope.SynTraceProjectIds.SequenceEqual(new[] { "p1" }))
            throw new InvalidOperationException("Disconnected Jira sources must be unavailable to the assistant.");
    }

    private static async Task CheckMeetingGatewayAsync(AssistantProjectAccess projectAccess)
    {
        var permissions = new TestPermissions();
        var factory = new TestHttpFactory();
        var config = Options.Create(new AiServiceOptions
        {
            BaseUrl = "https://ai.example.test", ApiKey = "test-internal",
            EnableMeetingContract = true, EnableSynTraceProjectScope = true
        });
        var gateway = new MeetingGateway(new TestTenant(), new TestEmployee(), permissions,
            projectAccess, factory, config);

        var create = new CreateMeetingRequest("TEAM", "note", "Planning", null, "Some notes", null, null);
        await ExpectStatus(403, () => gateway.CreateAsync(create, default));
        if (factory.Calls != 0) throw new InvalidOperationException("Unauthorized meeting requests must not reach AI.");
        permissions.Grants.UnionWith([MeetingPermission.Create, MeetingPermission.ReadPending]);
        await ExpectStatus(403, () => gateway.CreateAsync(create with { ProjectKey = "OTHER" }, default));
        if (factory.Calls != 0) throw new InvalidOperationException("Project scope must be checked before upload.");
        var accepted = await gateway.CreateAsync(create, default);
        if (accepted.StatusCode != 202 || factory.LastPayload is null)
            throw new InvalidOperationException("Meeting upload must preserve the AI 202 response.");
        using (var payload = JsonDocument.Parse(factory.LastPayload))
        {
            var json = payload.RootElement;
            var projects = json.GetProperty("allowedProjects").EnumerateArray().Select(x => x.GetString()).ToArray();
            if (json.GetProperty("companyId").GetString() != "a" || json.GetProperty("createdBy").GetString() != "employee" ||
                !projects.SequenceEqual(new[] { "TEAM", "p1" }))
                throw new InvalidOperationException("Meeting scope and actor must come from the backend.");
        }

        // Client sends explicit permission booleans and the complete history under the new contract.
        var assistantClient = new AssistantClient(factory, config, NullLogger<AssistantClient>.Instance);
        var history = Enumerable.Range(0, 20).Select(i => new AssistantHistoryTurn("q" + i, "a" + i)).ToArray();
        var scope = new AssistantProjectScope(["TEAM"], ["p1"])
        {
            MeetingPermissions = new MeetingAssistantPermissions(true, false, false, false)
        };
        var reply = await assistantClient.AskAsync("question", "a", "employee", scope, "correlation",
            "jira-account", "chat-id", history, [], [], false, default);
        if (reply.Failure != AssistantFailure.None || factory.LastPayload is null)
            throw new InvalidOperationException("Assistant wire contract test failed.");
        using (var payload = JsonDocument.Parse(factory.LastPayload))
        {
            var json = payload.RootElement;
            if (json.GetProperty("history").GetArrayLength() != 20 ||
                json.GetProperty("jiraAccountId").GetString() != "jira-account" ||
                !json.GetProperty("permissions").GetProperty("canReadApprovedMeetings").GetBoolean() ||
                json.GetProperty("permissions").GetProperty("canApproveMeeting").GetBoolean())
                throw new InvalidOperationException("Assistant payload must contain explicit permissions, Jira identity and all 20 turns.");
        }
        await ExpectStatus(403, () => gateway.ReviewAsync("source", new ReviewMeetingRequest([], [], null), default));
        permissions.Grants.Add(MeetingPermission.Approve);
        factory.State = "approved";
        await ExpectStatus(409, () => gateway.ReviewAsync("source", new ReviewMeetingRequest([], [], null), default));
        await ExpectStatus(403, () => gateway.GetAsync("source", default));
        permissions.Grants.UnionWith([MeetingPermission.ReadApproved, MeetingPermission.ExportPdf]);
        factory.State = "pending_review";
        await ExpectStatus(409, () => gateway.GetPdfAsync("source", default));
        factory.Project = "OTHER";
        await ExpectStatus(404, () => gateway.GetAsync("source", default));
        config.Value.EnableMeetingContract = false;
        await ExpectStatus(503, () => gateway.GetAsync("source", default));
    }

    private static async Task ExpectStatus(int status, Func<Task> action)
    {
        try { await action(); }
        catch (RequestFailureException ex) when (ex.StatusCode == status) { return; }
        throw new InvalidOperationException($"Expected meeting status {status}.");
    }

    private sealed class TestTenant : ICurrentTenant { public string CompanyId => "a"; }
    private sealed class TestEmployee : ICurrentEmployee { public string EmployeeId => "employee"; }
    private sealed class TestPermissions : IMeetingPermissionService
    {
        public HashSet<string> Grants { get; } = new(StringComparer.Ordinal);
        public Task<IReadOnlySet<string>> GetForEmployeeAsync(string companyId, string employeeId, CancellationToken ct) =>
            Task.FromResult<IReadOnlySet<string>>(Grants);
        public Task<IReadOnlyList<string>> GetForRoleAsync(string roleId, CancellationToken ct) => throw new NotSupportedException();
        public Task<IReadOnlyList<string>> ReplaceForRoleAsync(string roleId, IReadOnlyList<string> grants, CancellationToken ct) =>
            throw new NotSupportedException();
    }

    private sealed class TestHttpFactory : IHttpClientFactory
    {
        public int Calls { get; private set; }
        public string? LastPayload { get; private set; }
        public string State { get; set; } = "pending_review";
        public string Project { get; set; } = "TEAM";
        public HttpClient CreateClient(string name) => new(new Handler(this));

        private sealed class Handler(TestHttpFactory owner) : HttpMessageHandler
        {
            protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
            {
                owner.Calls++;
                if (!request.Headers.TryGetValues("X-Internal-Api-Key", out var keys) || keys.Single() != "test-internal")
                    throw new InvalidOperationException("Internal key must be set on all AI calls.");
                owner.LastPayload = request.Content is null ? null : await request.Content.ReadAsStringAsync(ct);
                if (request.RequestUri!.AbsolutePath == "/ask")
                    return new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = JsonContent.Create(new { status = "ok", answer = "answer", links = Array.Empty<object>(), correlationId = "correlation" })
                    };
                if (request.Method == HttpMethod.Post && request.RequestUri.AbsolutePath == "/meetings")
                    return new HttpResponseMessage(HttpStatusCode.Accepted)
                    {
                        Content = JsonContent.Create(new { status = "processing" })
                    };
                if (request.Method == HttpMethod.Get && request.RequestUri.AbsolutePath == "/meetings/source")
                    return new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = JsonContent.Create(new { sourceId = "source", projectKey = owner.Project, status = owner.State })
                    };
                throw new InvalidOperationException("Unexpected AI request in meeting integration check.");
            }
        }
    }
}
