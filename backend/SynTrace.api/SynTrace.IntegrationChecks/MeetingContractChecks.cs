using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Application.Contracts.Meetings;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Services.Assistant;
using SynTrace.Infrastructure.Services.Meetings;

/// <summary>Meeting routes added for the app (retry, list, project memory, live sessions, corrections)
/// and the chat fields passed through (choices, meeting, transcript). The AI is a fake handler.</summary>
internal static class MeetingContractChecks
{
    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        await using var db = new SynTraceDbContext(new DbContextOptionsBuilder<SynTraceDbContext>()
            .UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();
        var company = new Company { CompanyId = "a", CompanyName = "Company A" };
        var employee = new Employee { Id = "employee", CompanyId = "a", FirstName = "Test", LastName = "Member" };
        var client = new Client { ClientId = "client-a", CompanyId = "a", ClientName = "Client A" };
        db.AddRange(company, employee, client);
        db.AddRange(new JiraProject { Id = "jira-p1", CompanyId = "a", Key = "TEAM", ExternalId = "10001" },
            new JiraProject { Id = "jira-p2", CompanyId = "a", Key = "OTHER", ExternalId = "10002" });
        db.AddRange(
            new Project { ProjectId = "p1", CompanyId = "a", ClientId = "client-a", ProjectName = "Team", JiraProjectId = "jira-p1" },
            new Project { ProjectId = "p2", CompanyId = "a", ClientId = "client-a", ProjectName = "Other", JiraProjectId = "jira-p2" });
        db.Add(new EmployeeProject { EmployeeId = "employee", CompanyId = "a", ProjectId = "p1", Role = "Member" });
        db.Add(new JiraConnection { Id = "jira-install", CompanyId = "a", ConnectedByEmployeeId = "employee",
            JiraConnectionType = JiraConnectionType.Company });
        await db.SaveChangesAsync();

        var permissions = new Grants();
        var ai = new FakeAi();
        var config = Options.Create(new AiServiceOptions
        {
            BaseUrl = "https://ai.example.test", ApiKey = "test-internal", EnableMeetingContract = true
        });
        var gateway = new MeetingGateway(new Tenant(), new Actor(), permissions,
            new AssistantProjectAccess(db, new ProjectIntegrationAccess(db)), ai, config);

        // Retry: only a failed meeting, only with Create.
        await Expect(403, () => gateway.RetryAsync("source", default));
        permissions.Set.UnionWith([MeetingPermission.Create, MeetingPermission.ReadPending]);
        ai.State = "pending_review";
        await Expect(409, () => gateway.RetryAsync("source", default));
        ai.State = "failed";
        var retried = await gateway.RetryAsync("source", default);
        Check(retried.StatusCode == 202 && ai.Last == "POST /meetings/source/retry", "retry goes to the AI");

        // List: without ReadPending only approved meetings, and only accessible projects.
        permissions.Set.Clear();
        permissions.Set.Add(MeetingPermission.ReadApproved);
        await gateway.ListAsync("team", null, default);
        Check(ai.Last == "GET /projects/TEAM/meetings" && ai.Query.Contains("status=approved"),
            "a reader without ReadPending sees approved meetings only");
        await Expect(403, () => gateway.ListAsync("TEAM", "failed", default));
        await Expect(403, () => gateway.ListAsync("OTHER", null, default));
        await Expect(400, () => gateway.ListAsync("TEAM", "done", default));

        // Project memory.
        await gateway.GetRequirementsAsync("TEAM", "login & sso", default);
        Check(ai.Last == "GET /projects/TEAM/requirements" && ai.Query.Contains("q=login%20%26%20sso"),
            "requirement search text is encoded");
        await gateway.GetOpenQuestionsAsync("p1", default);
        Check(ai.Last == "GET /projects/p1/open-questions", "open questions of a SynTrace project id");
        await Expect(403, () => gateway.EditRequirementAsync("r1", new EditRequirementRequest("x"), default));
        permissions.Set.Add(MeetingPermission.Edit);
        await Expect(400, () => gateway.EditRequirementAsync("r1", new EditRequirementRequest(new string('x', 401)), default));
        await Expect(400, () => gateway.EditRequirementAsync("../r1", new EditRequirementRequest("x"), default));
        await gateway.EditRequirementAsync("r1", new EditRequirementRequest("  Login with SSO  "), default);
        Check(ai.Last == "PATCH /requirements/r1" && Field(ai.Payload, "editedBy") == "employee" &&
              Field(ai.Payload, "text") == "Login with SSO", "the editor is the signed-in employee");

        // Live sessions: the backend picks the id; the transcript at the end needs Create.
        await Expect(403, () => gateway.StartLiveSessionAsync(new StartLiveSessionRequest("TEAM", "Sync"), default));
        permissions.Set.Add(MeetingPermission.ManageLiveSessions);
        await gateway.StartLiveSessionAsync(new StartLiveSessionRequest("TEAM", "Sync"), default);
        Check(ai.Last.StartsWith("PUT /live-sessions/") && Guid.TryParse(ai.Last["PUT /live-sessions/".Length..], out _) &&
              Field(ai.Payload, "startedBy") == "employee", "live session id is a backend GUID");
        await Expect(403, () => gateway.StartLiveSessionAsync(new StartLiveSessionRequest("OTHER", null), default));
        await Expect(400, () => gateway.AssistLiveSessionAsync("s1", new LiveAssistRequest("x", new string('q', 401), null), default));
        await gateway.AssistLiveSessionAsync("s1", new LiveAssistRequest(null, "what is left?", ["g1"]), default);
        Check(ai.Last == "POST /live-sessions/s1/assist" && Field(ai.Payload, "transcript") == "", "assist sends the transcript");
        await Expect(403, () => gateway.EndLiveSessionAsync("s1", new LiveEndRequest("Client: hi", null), default));
        await gateway.EndLiveSessionAsync("s1", new LiveEndRequest(null, null), default);
        Check(ai.Last == "POST /live-sessions/s1/end", "ending without a transcript needs no Create");
        await gateway.DeleteLiveSessionAsync("s1", default);
        Check(ai.Last == "DELETE /live-sessions/s1", "a live session can be dropped");

        // A correction links to an approved meeting of the same project.
        permissions.Set.UnionWith([MeetingPermission.Create, MeetingPermission.ReadPending]);
        var correction = new CreateMeetingRequest("TEAM", "note", "Fix", null, "Correct the date", null, null, "source");
        ai.State = "pending_review";
        await Expect(409, () => gateway.CreateAsync(correction, default));
        ai.State = "approved";
        await gateway.CreateAsync(correction, default);
        Check(ai.Last == "POST /meetings" && Field(ai.Payload, "linkedSourceId") == "source", "the link reaches the AI");
        ai.Project = "p1";
        await Expect(400, () => gateway.CreateAsync(correction, default));
        ai.Project = "TEAM";

        // The AI's own limits.
        permissions.Set.UnionWith([MeetingPermission.Edit, MeetingPermission.UseAgent]);
        ai.State = "pending_review";
        await Expect(400, () => gateway.EditDocumentAsync("source", new EditMeetingDocumentRequest(new string('x', 40_001)), default));
        using (var number = JsonDocument.Parse("5"))
            await Expect(400, () => gateway.RewriteDocumentAsync("source",
                new RewriteMeetingDocumentRequest("clearer", number.RootElement.Clone()), default));
        await Expect(400, () => gateway.RewriteDocumentAsync("source",
            new RewriteMeetingDocumentRequest(new string('i', 501), null), default));

        // Delete needs its own permission.
        await Expect(403, () => gateway.DeleteAsync("source", default));
        permissions.Set.Add(MeetingPermission.Delete);
        var deleted = await gateway.DeleteAsync("source", default);
        Check(deleted.StatusCode == 204 && ai.Last == "DELETE /meetings/source", "delete reaches the AI");

        // Chat: transcript out, choices and meeting back.
        var assistant = new AssistantClient(ai, config, NullLogger<AssistantClient>.Instance);
        var scope = new AssistantProjectScope(["TEAM"], ["p1"]);
        var reply = await assistant.AskAsync("help", "a", "employee", scope, "c1", null, "chat", [], [], [], true,
            default, transcript: "Client: we need SSO", meetingDate: "2026-11-28");
        Check(Field(ai.Payload, "transcript") == "Client: we need SSO" && Field(ai.Payload, "meetingDate") == "2026-11-28",
            "the pasted transcript reaches the AI");
        Check(reply.Answer?.Choices?.SequenceEqual(["SYNT", "TEAM"]) == true &&
              reply.Answer.Meeting?.GetProperty("needsProject").GetBoolean() == true, "choices and meeting come back");
        config.Value.EnableMeetingContract = false;
        await assistant.AskAsync("help", "a", "employee", scope, "c2", null, "chat", [], [], [], true, default,
            transcript: "Client: we need SSO");
        Check(Field(ai.Payload, "transcript") is null, "no transcript without the meeting contract");
    }

    private static string? Field(string? json, string name)
    {
        if (json is null) return null;
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString() : null;
    }

    private static void Check(bool ok, string what)
    {
        if (!ok) throw new InvalidOperationException("Meeting contract check failed: " + what + ".");
    }

    private static async Task Expect(int status, Func<Task> action)
    {
        try { await action(); }
        catch (RequestFailureException ex) when (ex.StatusCode == status) { return; }
        catch (RequestFailureException ex)
        {
            throw new InvalidOperationException($"Expected meeting status {status}, got {ex.StatusCode}: {ex.Message}");
        }
        throw new InvalidOperationException($"Expected meeting status {status}.");
    }

    private sealed class Tenant : ICurrentTenant { public string CompanyId => "a"; }
    private sealed class Actor : ICurrentEmployee { public string EmployeeId => "employee"; }
    private sealed class Grants : IMeetingPermissionService
    {
        public HashSet<string> Set { get; } = new(StringComparer.Ordinal);
        public Task<IReadOnlySet<string>> GetForEmployeeAsync(string companyId, string employeeId, CancellationToken ct) =>
            Task.FromResult<IReadOnlySet<string>>(new HashSet<string>(Set, StringComparer.Ordinal));
        public Task<IReadOnlyList<string>> GetForRoleAsync(string roleId, CancellationToken ct) => throw new NotSupportedException();
        public Task<IReadOnlyList<string>> ReplaceForRoleAsync(string roleId, IReadOnlyList<string> grants, CancellationToken ct) =>
            throw new NotSupportedException();
    }

    private sealed class FakeAi : IHttpClientFactory
    {
        public string State { get; set; } = "pending_review";
        public string Project { get; set; } = "TEAM";
        public string Last { get; private set; } = "";
        public string Query { get; private set; } = "";
        public string? Payload { get; private set; }
        public HttpClient CreateClient(string name) => new(new Handler(this));

        private sealed class Handler(FakeAi owner) : HttpMessageHandler
        {
            protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
            {
                var path = request.RequestUri!.AbsolutePath;
                var body = request.Content is null ? null : await request.Content.ReadAsStringAsync(ct);
                // Reading the meeting first is the gateway's own check; keep the last real call.
                if (request.Method == HttpMethod.Get && path == "/meetings/source")
                    return Json(HttpStatusCode.OK, new { sourceId = "source", projectKey = owner.Project, status = owner.State });
                owner.Last = request.Method.Method + " " + path;
                owner.Query = request.RequestUri.Query;
                owner.Payload = body;
                if (path == "/ask")
                    return Json(HttpStatusCode.OK, new
                    {
                        status = "ok", answer = "Which project?", links = Array.Empty<object>(), correlationId = "c",
                        choices = new[] { "SYNT", "TEAM" }, meeting = new { needsProject = true }
                    });
                if (request.Method == HttpMethod.Delete)
                    return new HttpResponseMessage(HttpStatusCode.NoContent);
                var code = request.Method == HttpMethod.Post && (path == "/meetings" || path.EndsWith("/retry"))
                    ? HttpStatusCode.Accepted : HttpStatusCode.OK;
                return Json(code, new { status = "processing" });
            }

            private static HttpResponseMessage Json(HttpStatusCode code, object body) =>
                new(code) { Content = JsonContent.Create(body) };
        }
    }
}
