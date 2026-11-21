using Microsoft.AspNetCore.Identity;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Knowledge;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Knowledge;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Services.Knowledge;

internal static class KnowledgeSourceChecks
{
    public static async Task RunAsync()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var actor = new Actor();
        await using var db = new SynTraceDbContext(
            new DbContextOptionsBuilder<SynTraceDbContext>().UseSqlite(connection).Options, actor);
        await db.Database.EnsureCreatedAsync();
        db.Companies.AddRange(
            new Company { CompanyId = "company", CompanyName = "Company" },
            new Company { CompanyId = "foreign-company", CompanyName = "Foreign company" });
        db.Employees.AddRange(
            Employee("author", "company"), Employee("manager", "company"), Employee("reader", "company"),
            Employee("foreigner", "foreign-company"));
        db.Clients.Add(new Client { ClientId = "client", CompanyId = "company", ClientName = "Client" });
        db.Projects.Add(new Project { ProjectId = "project", CompanyId = "company", ClientId = "client", ProjectName = "Project" });
        db.EmployeeProjects.AddRange(Member("author", "Member"), Member("manager", "ProjectManager"), Member("reader", "Member"));
        db.Roles.Add(new Role { Id = "manager-role", CompanyId = "company", Name = "Project Manager", NormalizedName = "PROJECT MANAGER" });
        db.UserRoles.Add(new IdentityUserRole<string> { UserId = "manager", RoleId = "manager-role" });
        await db.SaveChangesAsync();

        var service = new KnowledgeSourceService(db, actor, actor, new ProjectIntegrationAccess(db));
        var created = await service.CreateAsync(new CreateKnowledgeSourceRequest
        {
            ClientId = "client", ProjectId = "project", Kind = KnowledgeSourceKind.MeetingNotes, Title = "Client meeting",
            MeetingMode = KnowledgeMeetingMode.InPerson, MeetingAt = DateTimeOffset.UtcNow
        }, new KnowledgeContent("text/plain", "Add an export. Report latency.", null, null), default);
        var id = created.Id;
        Check(created.Version == 1 && created.Status == KnowledgeSourceStatus.PendingExtraction, "Meeting notes enter extraction.");

        actor.EmployeeId = "reader";
        await ExpectStatusAsync(404, () => service.ReadAsync(id, null, default));
        Check((await service.ListAsync(null, "project", 0, 10, default)).Count == 0, "Drafts stay out of a member's list.");

        actor.EmployeeId = "author";
        await ExpectStatusAsync(400, () => service.SubmitManualExtractionAsync(id, 1,
            new KnowledgeExtractionRequest([new(KnowledgeEvidenceKind.Requirement, "Export", "Missing quote")], null, null), default));
        await service.SubmitManualExtractionAsync(id, 1, new KnowledgeExtractionRequest([
                new(KnowledgeEvidenceKind.Requirement, "Export", "Add an export."),
                new(KnowledgeEvidenceKind.OpenQuestion, "Latency", "Report latency.")], null, null), default);
        var draft = await service.ReadAsync(id, null, default);
        var decisions = draft.Evidence.Select(e => new KnowledgeEvidenceReview(e.Id, e.Text == "Export")).ToArray();
        await ExpectStatusAsync(403, () => service.ReviewAsync(id, 1, new KnowledgeReviewRequest(decisions, true), default));
        Check((await service.ReadChangesAsync("company", 0, 10, default)).Count == 0, "Unreviewed evidence produces no publication event.");

        actor.EmployeeId = "manager";
        await service.ReviewAsync(id, 1, new KnowledgeReviewRequest(decisions, true), default);
        actor.EmployeeId = "reader";
        var published = await service.ReadAsync(id, null, default);
        Check(published is { SourceText: null, Evidence: [{ Text: "Export", QuoteOffset: 0 }] }, "Members see only approved evidence.");
        Check((await service.ListAsync("client", "project", 0, 10, default)) is [{ PublishedVersion: 1 }], "Publishing updates the member's list.");

        actor.EmployeeId = "author";
        await service.AddVersionAsync(id, new AddKnowledgeVersionRequest
        {
            ExpectedVersion = 1, Title = "Client meeting updated", MeetingMode = KnowledgeMeetingMode.InPerson,
            MeetingAt = DateTimeOffset.UtcNow
        }, new KnowledgeContent("text/plain", "Change export.", null, null), default);
        actor.EmployeeId = "reader";
        Check((await service.ReadAsync(id, null, default)).Source.Version == 1, "A new draft preserves the earlier publication.");

        actor.CompanyId = "foreign-company";
        actor.EmployeeId = "foreigner";
        await ExpectStatusAsync(404, () => service.ReadAsync(id, null, default));
        await ExpectStatusAsync(404, () => service.ReadPublishedAsync(actor.CompanyId, "project", id, 1, default));
        Check((await service.PendingAsync(actor.CompanyId, 5, default)).Count == 0, "The worker queue is tenant-scoped.");

        actor.CompanyId = "company";
        actor.EmployeeId = "manager";
        await service.WithdrawAsync(id, default);
        await ExpectStatusAsync(404, () => service.ReadPublishedAsync("company", "project", id, 1, default));
        var changes = await service.ReadChangesAsync("company", 0, 10, default);
        Check(changes is [{ Removed: false }, { Removed: true }] && changes[0].Cursor < changes[1].Cursor,
            "The graph feed records publication and withdrawal in order.");

        var pdf = "%PDF-1.7"u8.ToArray();
        var clientSource = await service.CreateAsync(new CreateKnowledgeSourceRequest
        {
            ClientId = "client", Kind = KnowledgeSourceKind.Requirements, Title = "First client requirements"
        }, new KnowledgeContent("application/pdf", null, pdf, "requirements.pdf"), default);
        Check((await service.ReadPendingPdfAsync("company", clientSource.Id, 1, default)).SequenceEqual(pdf),
            "The client source retains the uploaded PDF for extraction.");
        await service.SubmitInternalExtractionAsync("company", clientSource.Id, 1, new KnowledgeExtractionRequest(
            [new(KnowledgeEvidenceKind.Requirement, "Sign in", "Users must sign in.")], "Users must sign in.", null), default);
        var beforeLink = await service.ReadAsync(clientSource.Id, 1, default);
        await service.ReviewAsync(clientSource.Id, 1,
            new KnowledgeReviewRequest([new(beforeLink.Evidence.Single().Id, true)], true), default);
        Check((await service.ReadChangesAsync("company", changes[^1].Cursor, 10, default)).Count == 0,
            "Client-only approval stays outside the project graph feed.");
        await service.LinkProjectAsync(clientSource.Id, "project", default);
        Check((await service.ReadAsync(clientSource.Id, null, default)).Source.Status == KnowledgeSourceStatus.AwaitingReview,
            "Linking a client source to a project requires fresh review.");
        actor.EmployeeId = "reader";
        await ExpectStatusAsync(404, () => service.ReadAsync(clientSource.Id, null, default));
    }

    private static Employee Employee(string id, string company) => new()
    {
        Id = id, CompanyId = company, FirstName = id, LastName = "Tester"
    };

    private static EmployeeProject Member(string employeeId, string role) => new()
    {
        EmployeeId = employeeId, CompanyId = "company", ProjectId = "project", Role = role
    };

    private static async Task ExpectStatusAsync(int status, Func<Task> action)
    {
        try { await action(); }
        catch (KnowledgeSourceException e) when (e.Status == status) { return; }
        throw new InvalidOperationException($"Expected knowledge sources to return {status}.");
    }

    private static void Check(bool value, string message)
    {
        if (!value)
            throw new InvalidOperationException(message);
    }

    private sealed class Actor : ICurrentTenant, ICurrentEmployee
    {
        public string CompanyId { get; set; } = "company";
        public string EmployeeId { get; set; } = "author";
    }
}
