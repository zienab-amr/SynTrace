using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Application.Messaging;
using SynTrace.Contracts.IntegrationEvents.Jira;
using SynTrace.Contracts.IntegrationEvents.Jira.Payloads;
using SynTrace.Contracts.Serialization;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Enums;
using SynTrace.Domain.Enums.Jira;
using SynTrace.Infrastructure.Integrations.Jira;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Repositories;

internal static class JiraProjectionChecks
{
    private const string CompanyId = "jira-fixture-company";
    private const string ConnectionId = "jira-fixture-connection";
    private const string OtherCompanyId = "jira-other-company";
    private const string OtherConnectionId = "jira-other-connection";
    private static readonly DateTimeOffset FirstEvent = DateTimeOffset.Parse("2026-01-02T00:00:00Z");

    public static async Task RunAsync()
    {
        await using var database = new SqliteConnection("Data Source=:memory:");
        await database.OpenAsync();
        var options = new DbContextOptionsBuilder<SynTraceDbContext>().UseSqlite(database).Options;
        await using var db = new SynTraceDbContext(options);
        await db.Database.EnsureCreatedAsync();
        var protection = new EphemeralDataProtectionProvider();
        var token = protection.CreateProtector("SynTrace.Integrations.Jira.Tokens.v1").Protect("fixture-token");
        SeedConnection(db, CompanyId, ConnectionId, token);
        SeedConnection(db, OtherCompanyId, OtherConnectionId, token);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var processor = new JiraEventProcessor(db, NullLogger<JiraEventProcessor>.Instance);
        async Task<JiraEventProcessingResult> Apply(CanonicalJiraEvent message)
        {
            var result = await processor.ProcessAsync(message, CancellationToken.None);
            db.ChangeTracker.Clear();
            return result;
        }

        var created = ProjectWebhook("project_created", "100", "START", "First title", 0);
        var updated = ProjectWebhook("project_updated", "100", "NEW", "Current title", 2);
        var stored = updated.Payload.Deserialize<JiraProjectPayload>(JiraEventContractJson.Options);
        Expect(stored is { ProjectId: "100", ProjectKey: "NEW", Name: "Current title", LeadAccountId: "fixture-lead" },
            "Project webhooks normalize the ID, key, title and lead.");
        Expect(await Apply(created) == JiraEventProcessingResult.Processed, "A project create is processed.");
        // Simulate a message queued before the project normalizer was fixed.
        var legacyUpdate = updated with { Payload = JsonSerializer.SerializeToElement(new { }) };
        await Apply(legacyUpdate);
        Expect(await Apply(legacyUpdate) == JiraEventProcessingResult.Duplicate, "A redelivery is identified by its ledger entry.");
        await Apply(ProjectWebhook("project_updated", "100", "OLD", "Older title", 1));
        var liveProjects = db.JiraProjects.IgnoreQueryFilters().Where(p => p.CompanyId == CompanyId);
        Expect(await liveProjects.AnyAsync(p => p.ExternalId == "100" && p.Key == "NEW" && p.Name == "Current title"),
            "A stale project update cannot overwrite the current project.");

        var other = updated with { CompanyId = OtherCompanyId, JiraConnectionId = OtherConnectionId };
        await Apply(other);
        await Apply(IssueEvent(JiraEventType.IssueCreated, "101", "100", 3));
        await Apply(IssueEvent(JiraEventType.IssueCreated, "101", "100", 3) with
        {
            CompanyId = OtherCompanyId,
            JiraConnectionId = OtherConnectionId
        });
        await Apply(IssueEvent(JiraEventType.IssueDeleted, "101", "100", 5));
        await Apply(IssueEvent(JiraEventType.IssueUpdated, "101", "100", 4));
        var issues = db.JiraIssues.IgnoreQueryFilters();
        Expect(!await issues.AnyAsync(i => i.CompanyId == CompanyId && i.ExternalId == "101") &&
            await issues.AnyAsync(i => i.CompanyId == OtherCompanyId && i.ExternalId == "101"),
            "A deleted issue remains absent after delayed activity, and another company's issue survives.");

        await Apply(ProjectWebhook("project_created", "200", "REMOVED", "Removed project", 0));
        await Apply(IssueEvent(JiraEventType.IssueCreated, "201", "200", 3));
        await Apply(ProjectWebhook("project_deleted", "200", "REMOVED", "Removed project", 6));
        await Apply(IssueEvent(JiraEventType.IssueUpdated, "201", "200", 5));
        await Apply(CommentEvent(JiraEventType.CommentDeleted, "301", "102", 5));
        Expect(!await liveProjects.AnyAsync(p => p.ExternalId == "200") &&
            !await issues.AnyAsync(i => i.CompanyId == CompanyId && i.ExternalId == "201"),
            "A deleted project and its issues remain absent after delayed activity.");

        using var http = new HttpClient(new JiraBackfillResponses());
        var api = new JiraApiClient(db, new FixtureClientFactory(http), Options.Create(new JiraOAuthOptions()),
            new JiraOAuthConnectionRepository(db), protection);
        var backfill = new JiraBackfillService(db, api, new ExistingImport(), NullLogger<JiraBackfillService>.Instance);
        await backfill.RunAsync(ConnectionId, CancellationToken.None);
        Expect(await db.JiraConnections.AnyAsync(c => c.Id == ConnectionId && c.SyncStatus == JiraSyncStatus.Completed),
            "The regular Jira backfill completes.");
        Expect(!await liveProjects.AnyAsync(p => p.ExternalId == "200") &&
            !await issues.AnyAsync(i => i.CompanyId == CompanyId && (i.ExternalId == "101" || i.ExternalId == "201")),
            "A delayed REST response cannot revive deleted Jira projects or issues.");
        var comments = db.JiraComments.IgnoreQueryFilters().Where(c => c.CompanyId == CompanyId);
        Expect(await issues.AnyAsync(i => i.CompanyId == CompanyId && i.ExternalId == "102") &&
            await comments.AnyAsync(c => c.ExternalId == "302") && !await comments.AnyAsync(c => c.ExternalId == "301"),
            "The same backfill imports surviving Jira issues and comments.");
    }

    private static CanonicalJiraEvent ProjectWebhook(string kind, string id, string key, string name, int minutes)
    {
        var time = FirstEvent.AddMinutes(minutes);
        var json = JsonSerializer.SerializeToElement(new
        {
            webhookEvent = kind, timestamp = time.ToUnixTimeMilliseconds(),
            project = new { id, key, name, lead = new { accountId = "fixture-lead" } }
        });
        return new JiraWebhookNormalizer().Normalize(json, CompanyId, ConnectionId, "cloud", "https://fixture.atlassian.net",
            "fixture-request", time) ?? throw new InvalidOperationException("Fixture project webhook was ignored.");
    }

    private static CanonicalJiraEvent IssueEvent(JiraEventType type, string id, string projectId, int minutes) =>
        Event(type, id, minutes, new JiraIssuePayload
        {
            IssueId = id, IssueKey = $"FIX-{id}", ProjectId = projectId, ProjectKey = "FIX",
            SourceUpdatedAtUtc = FirstEvent.AddMinutes(minutes)
        });

    private static CanonicalJiraEvent CommentEvent(JiraEventType type, string id, string issueId, int minutes) =>
        Event(type, id, minutes, new JiraCommentPayload { CommentId = id, IssueId = issueId, ProjectId = "100" });

    private static CanonicalJiraEvent Event<T>(JiraEventType type, string id, int minutes, T payload) => new()
    {
        EventId = $"{type}-{id}-{minutes}",
        EventType = type,
        CompanyId = CompanyId,
        JiraConnectionId = ConnectionId,
        ReceivedAtUtc = FirstEvent.AddMinutes(minutes),
        OccurredAtUtc = FirstEvent.AddMinutes(minutes),
        Payload = JsonSerializer.SerializeToElement(payload, JiraEventContractJson.Options)
    };

    private static void SeedConnection(SynTraceDbContext db, string companyId, string connectionId, string token)
    {
        var employeeId = companyId + "-admin";
        db.Companies.Add(new Company { CompanyId = companyId, CompanyName = companyId });
        db.Employees.Add(new Employee { Id = employeeId, CompanyId = companyId, FirstName = "Fixture", LastName = "Admin" });
        db.JiraConnections.Add(new JiraConnection
        {
            Id = connectionId, CompanyId = companyId, ConnectedByEmployeeId = employeeId,
            JiraConnectionType = JiraConnectionType.Company, CloudId = "cloud", SiteUrl = "https://fixture.atlassian.net",
            EncryptedAccessToken = token, AiImportCompletedAt = DateTime.UtcNow
        });
    }

    private sealed class FixtureClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class JiraBackfillResponses : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var body = request.RequestUri!.AbsolutePath["/ex/jira/cloud".Length..] switch
            {
                "/rest/api/3/users/search" => "[]",
                "/rest/api/3/project/search" => """
                    {"isLast":true,"values":[{"id":"100","key":"NEW","name":"Current title"},{"id":"200","key":"REMOVED"}]}
                    """,
                "/rest/api/3/search/jql" => """
                    {"issues":[{"id":"101","key":"NEW-1","fields":{"project":{"id":"100"},"updated":"2026-01-02T00:04:00Z"}},
                    {"id":"102","key":"NEW-2","fields":{"project":{"id":"100"},"updated":"2026-01-02T00:04:00Z",
                    "comment":{"total":2,"comments":[{"id":"301","body":"Removed","updated":"2026-01-02T00:04:00Z"},
                    {"id":"302","body":"Current","updated":"2026-01-02T00:04:00Z"}]}}}]}
                    """,
                "/rest/agile/1.0/board" => """{"isLast":true,"values":[]}""",
                _ => throw new InvalidOperationException($"Unexpected Jira fixture path {request.RequestUri.AbsolutePath}.")
            };
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(body) });
        }
    }

    private sealed class ExistingImport : IJiraEventPublisher
    {
        public Task PublishAsync(CanonicalJiraEvent message, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("The backfill should reuse the completed AI import.");
    }

    private static void Expect(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
}
