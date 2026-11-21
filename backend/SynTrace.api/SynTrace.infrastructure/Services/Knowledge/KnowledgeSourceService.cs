using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Knowledge;
using SynTrace.Domain.Entities.Knowledge;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Services.Knowledge;

public static class KnowledgeSourceRegistration
{
    public static IServiceCollection AddKnowledgeSources(this IServiceCollection services) =>
        services.AddScoped<KnowledgeSourceService>();
}

public sealed class KnowledgeSourceService(
    SynTraceDbContext db,
    ICurrentTenant tenant,
    ICurrentEmployee employee,
    ProjectIntegrationAccess projects)
{
    public const int MaxPdfBytes = 5 * 1024 * 1024;
    public const int MaxTextLength = 256_000;
    private DbSet<KnowledgeSource> Sources => db.Set<KnowledgeSource>();
    private DbSet<KnowledgeSourceVersion> Versions => db.Set<KnowledgeSourceVersion>();
    private DbSet<KnowledgePublicationChange> Changes => db.Set<KnowledgePublicationChange>();

    private sealed record Actor(string Company, string Employee, bool Admin, bool CanReviewClient);
    private sealed record SourceAccess(KnowledgeSource Source, Actor Actor, bool CanReview)
    {
        public bool CanEdit => CanReview || Source.CreatedByEmployeeId == Actor.Employee;
    }

    public async Task<KnowledgeSourceSummary> CreateAsync(CreateKnowledgeSourceRequest request,
        KnowledgeContent content, CancellationToken ct)
    {
        var actor = await GetActorAsync(ct);
        if (!Enum.IsDefined(request.Kind))
            throw Invalid("Choose Documentation, Requirements or MeetingNotes.");
        await EnsureScopeAsync(actor, request.ClientId, request.ProjectId, ct);

        var now = DateTime.UtcNow;
        var source = new KnowledgeSource
        {
            Id = Guid.NewGuid(), CompanyId = actor.Company, ClientId = request.ClientId,
            ProjectId = request.ProjectId, Kind = request.Kind, CreatedByEmployeeId = actor.Employee,
            CreatedAtUtc = now, UpdatedAtUtc = now, CurrentVersion = 1, Revision = 1
        };
        var version = BuildVersion(source, 1, actor.Employee, request.Title, content, request.MeetingMode, request.MeetingAt);
        Sources.Add(source);
        Versions.Add(version);
        await SaveAsync(ct);
        return Summary(source, version);
    }

    public async Task<KnowledgeSourceSummary> AddVersionAsync(Guid id, AddKnowledgeVersionRequest request,
        KnowledgeContent content, CancellationToken ct)
    {
        var access = await AccessAsync(id, ct);
        if (!access.CanEdit)
            throw Forbidden();
        var source = access.Source;
        if (source.CurrentVersion != request.ExpectedVersion)
            throw Conflict();
        var number = source.CurrentVersion + 1;
        var version = BuildVersion(source, number, access.Actor.Employee, request.Title, content, request.MeetingMode, request.MeetingAt);
        source.CurrentVersion = number;
        Touch(source);
        Versions.Add(version);
        await SaveAsync(ct);
        return Summary(source, version);
    }

    public async Task<IReadOnlyList<KnowledgeSourceSummary>> ListAsync(string? clientId, string? projectId,
        int skip, int take, CancellationToken ct)
    {
        var actor = await GetActorAsync(ct);
        var memberships = db.EmployeeProjects.AsNoTracking()
            .Where(x => x.CompanyId == actor.Company && x.EmployeeId == actor.Employee);
        var reviewerProjects = memberships.Where(x => x.Role.ToUpper() == "PO" || x.Role.ToUpper() == "PM" ||
            x.Role.ToUpper() == "PRODUCTOWNER" || x.Role.ToUpper() == "PROJECTMANAGER").Select(x => x.ProjectId);
        return await (from s in Sources.AsNoTracking()
                  join v in Versions.AsNoTracking() on s.Id equals v.SourceId
                  where s.CompanyId == actor.Company && !s.Withdrawn
                    && (clientId == null || s.ClientId == clientId)
                    && (projectId == null || s.ProjectId == projectId)
                    && (actor.Admin || (actor.CanReviewClient && s.ProjectId == null)
                        || (s.ProjectId != null && memberships.Any(m => m.ProjectId == s.ProjectId)))
                    && v.Number == (actor.Admin || (actor.CanReviewClient && s.ProjectId == null) || s.CreatedByEmployeeId == actor.Employee ||
                        (s.ProjectId != null && reviewerProjects.Contains(s.ProjectId))
                            ? s.CurrentVersion : s.PublishedVersion)
                  orderby s.UpdatedAtUtc descending, s.Id
                  select new KnowledgeSourceSummary(s.Id, s.ClientId, s.ProjectId, s.Kind, v.Title, v.Number,
                      s.PublishedVersion, v.Status)).Skip(skip).Take(take).ToListAsync(ct);
    }

    public async Task<KnowledgeSourceView> ReadAsync(Guid id, int? version, CancellationToken ct)
    {
        var access = await AccessAsync(id, ct);
        var source = access.Source;
        var number = version ?? (access.CanEdit ? source.CurrentVersion : source.PublishedVersion);
        if (number is null || (!access.CanEdit && number != source.PublishedVersion))
            throw Missing();
        var entity = await VersionAsync(source.Id, number.Value, ct);
        return View(source, entity, access.CanEdit);
    }

    public async Task SubmitManualExtractionAsync(Guid id, int version, KnowledgeExtractionRequest request, CancellationToken ct)
    {
        var access = await AccessAsync(id, ct);
        if (!access.CanEdit)
            throw Forbidden();
        await SubmitExtractionAsync(access.Source, version, request, ct);
    }

    public async Task SubmitInternalExtractionAsync(string companyId, Guid id, int version,
        KnowledgeExtractionRequest request, CancellationToken ct)
    {
        var source = await Sources.SingleOrDefaultAsync(x => x.CompanyId == companyId && x.Id == id && !x.Withdrawn, ct)
            ?? throw Missing();
        await SubmitExtractionAsync(source, version, request, ct);
    }

    public async Task ReviewAsync(Guid id, int version, KnowledgeReviewRequest request, CancellationToken ct)
    {
        var access = await AccessAsync(id, ct);
        if (!access.CanReview)
            throw Forbidden();
        var source = access.Source;
        var entity = await VersionAsync(id, version, ct);
        if (version != source.CurrentVersion || entity.Status != KnowledgeSourceStatus.AwaitingReview)
            throw Conflict();
        var decisions = request.Decisions ?? throw Invalid("An evidence decision list is required.");
        var valid = decisions.Count == entity.Evidence.Count && decisions.All(d => d is not null)
            && decisions.Select(d => d.Id).Distinct().Count() == decisions.Count
            && decisions.All(d => entity.Evidence.Any(e => e.Id == d.Id));
        if (!valid)
            throw Invalid("Send exactly one decision for each item of this version.");
        if (request.Publish && (decisions.Count == 0 || decisions.All(d => !d.Approve)))
            throw Invalid("Approve at least one item before publishing.");

        var byId = decisions.ToDictionary(d => d.Id, d => d.Approve);
        foreach (var evidence in entity.Evidence)
        {
            evidence.Decision = request.Publish && byId[evidence.Id]
                ? KnowledgeEvidenceDecision.Approved : KnowledgeEvidenceDecision.Rejected;
        }

        entity.Status = request.Publish ? KnowledgeSourceStatus.Published : KnowledgeSourceStatus.Rejected;
        entity.ReviewedAtUtc = DateTime.UtcNow;
        entity.ReviewedByEmployeeId = access.Actor.Employee;
        if (request.Publish)
        {
            source.PublishedVersion = version;
            RecordPublication(source, version, removed: false);
        }
        Touch(source);
        await SaveAsync(ct);
    }

    public async Task RetryAsync(Guid id, int version, CancellationToken ct)
    {
        var access = await AccessAsync(id, ct);
        if (!access.CanEdit)
            throw Forbidden();
        var entity = await VersionAsync(id, version, ct);
        if (version != access.Source.CurrentVersion || entity.Status != KnowledgeSourceStatus.ExtractionFailed)
            throw Conflict();
        entity.Status = KnowledgeSourceStatus.PendingExtraction;
        entity.FailureCode = null;
        Touch(access.Source);
        await SaveAsync(ct);
    }

    public async Task LinkProjectAsync(Guid id, string projectId, CancellationToken ct)
    {
        var access = await AccessAsync(id, ct);
        if (!access.CanEdit)
            throw Forbidden();
        var source = access.Source;
        if (source.ProjectId == projectId)
            return;
        if (source.ProjectId is not null)
            throw Invalid("This source already belongs to a project.");
        await EnsureScopeAsync(access.Actor, source.ClientId, projectId, ct);

        // Client-level approval doesn't make material public to a newly linked project.
        if (source.PublishedVersion is int published && published == source.CurrentVersion)
        {
            var reviewed = await VersionAsync(id, published, ct);
            reviewed.Status = KnowledgeSourceStatus.AwaitingReview;
            reviewed.ReviewedAtUtc = null;
            reviewed.ReviewedByEmployeeId = null;
            foreach (var evidence in reviewed.Evidence)
                evidence.Decision = KnowledgeEvidenceDecision.Pending;
        }
        source.PublishedVersion = null;
        source.ProjectId = projectId;
        Touch(source);
        await SaveAsync(ct);
    }

    public async Task WithdrawAsync(Guid id, CancellationToken ct)
    {
        var access = await AccessAsync(id, ct);
        var source = access.Source;
        if (!access.CanEdit || (source.PublishedVersion.HasValue && !access.CanReview))
            throw Forbidden();
        if (source.PublishedVersion is int published)
            RecordPublication(source, published, removed: true);
        source.Withdrawn = true;
        source.PublishedVersion = null;
        Touch(source);
        await SaveAsync(ct);
    }

    public async Task<IReadOnlyList<KnowledgeExtractionJob>> PendingAsync(string companyId, int take, CancellationToken ct) =>
        await (from s in Sources.AsNoTracking()
               join v in Versions.AsNoTracking() on s.Id equals v.SourceId
               where s.CompanyId == companyId && !s.Withdrawn && s.CurrentVersion == v.Number
                   && v.Status == KnowledgeSourceStatus.PendingExtraction
               orderby v.CreatedAtUtc, s.Id
               select new KnowledgeExtractionJob(s.Id, v.Number, s.ClientId, s.ProjectId, s.Kind,
                   v.Title, v.MediaType, v.Text, v.FileName)).Take(take).ToListAsync(ct);

    public async Task<byte[]> ReadPendingPdfAsync(string companyId, Guid id, int version, CancellationToken ct) =>
        await (from s in Sources.AsNoTracking()
               join v in Versions.AsNoTracking() on s.Id equals v.SourceId
               where s.CompanyId == companyId && !s.Withdrawn && s.Id == id && s.CurrentVersion == version
                   && v.Number == version && v.Status == KnowledgeSourceStatus.PendingExtraction
               select v.Pdf).SingleOrDefaultAsync(ct) ?? throw Missing();

    public async Task<IReadOnlyList<KnowledgeChange>> ReadChangesAsync(string companyId, long after, int take,
        CancellationToken ct) =>
        await Changes.AsNoTracking().Where(x => x.CompanyId == companyId && x.Id > after)
            .OrderBy(x => x.Id).Take(take)
            .Select(x => new KnowledgeChange(x.Id, x.SourceId, x.Version, x.ProjectId, x.Removed)).ToListAsync(ct);

    public async Task<KnowledgeSourceView> ReadPublishedAsync(string companyId, string projectId, Guid id, int version,
        CancellationToken ct)
    {
        var source = await Sources.AsNoTracking().SingleOrDefaultAsync(x => x.CompanyId == companyId
            && x.ProjectId == projectId && x.Id == id && !x.Withdrawn && x.PublishedVersion == version, ct)
            ?? throw Missing();
        var entity = await VersionAsync(id, version, ct);
        return View(source, entity, canEdit: false);
    }

    private async Task SubmitExtractionAsync(KnowledgeSource source, int version, KnowledgeExtractionRequest request, CancellationToken ct)
    {
        var entity = await VersionAsync(source.Id, version, ct);
        if (version != source.CurrentVersion || entity.Status is not
            (KnowledgeSourceStatus.PendingExtraction or KnowledgeSourceStatus.ExtractionFailed))
            throw Conflict();

        if (request.FailureCode is string code)
        {
            if (code is not ("Unreadable" or "ExtractionUnavailable" or "TimedOut") ||
                (request.Items?.Count ?? 0) > 0 || request.ExtractedText is not null)
                throw Invalid("Use a documented failure code without extracted text or evidence.");
            entity.FailureCode = code;
            entity.Status = KnowledgeSourceStatus.ExtractionFailed;
        }
        else
        {
            var sourceText = entity.MediaType == "application/pdf" ? request.ExtractedText ?? entity.Text : entity.Text;
            if (string.IsNullOrWhiteSpace(sourceText) || sourceText.Length > MaxTextLength)
                throw Invalid("Supply the PDF transcript, up to 256,000 characters. Text files use the saved text.");
            var inputs = request.Items ?? throw Invalid("An evidence list is required.");
            if (inputs.Count > 100)
                throw Invalid("Submit up to 100 evidence items.");
            var next = new List<KnowledgeEvidence>();
            foreach (var input in inputs)
            {
                if (input is null || !Enum.IsDefined(input.Kind) || string.IsNullOrWhiteSpace(input.Text) || input.Text.Length > 2000 ||
                    string.IsNullOrWhiteSpace(input.Quote) || input.Quote.Length > 4000)
                    throw Invalid("Each item needs a valid kind, summary and verbatim source quote.");
                var index = sourceText.IndexOf(input.Quote, StringComparison.Ordinal);
                if (index < 0)
                    throw Invalid("An evidence quote must occur verbatim in the saved source transcript.");
                if (next.Any(x => x.Kind == input.Kind && x.Quote == input.Quote && x.Text == input.Text.Trim()))
                    continue;
                next.Add(new KnowledgeEvidence
                {
                    Id = Guid.NewGuid(), SourceId = source.Id, Version = version, Kind = input.Kind,
                    Text = input.Text.Trim(), Quote = input.Quote, QuoteOffset = index
                });
            }
            entity.Text = sourceText;
            entity.Evidence.AddRange(next);
            entity.FailureCode = null;
            entity.Status = KnowledgeSourceStatus.AwaitingReview;
        }

        Touch(source);
        await SaveAsync(ct);
    }

    private async Task<Actor> GetActorAsync(CancellationToken ct)
    {
        var company = tenant.CompanyId;
        var actor = employee.EmployeeId;
        if (!await db.Employees.AnyAsync(e => e.Id == actor && e.CompanyId == company, ct))
            throw Forbidden();
        var admin = await projects.IsCompanyAdminAsync(company, actor, ct);
        var canReviewClient = admin || await (from membership in db.UserRoles
            join role in db.Roles on membership.RoleId equals role.Id
            where membership.UserId == actor && role.CompanyId == company
                && (role.NormalizedName == "PRODUCT OWNER" || role.NormalizedName == "PROJECT MANAGER")
            select role.Id).AnyAsync(ct);
        return new Actor(company, actor, admin, canReviewClient);
    }

    private async Task EnsureScopeAsync(Actor actor, string clientId, string? projectId, CancellationToken ct)
    {
        if (!await db.Clients.AnyAsync(c => c.ClientId == clientId && c.CompanyId == actor.Company, ct))
            throw Missing();
        if (projectId is null)
        {
            if (!actor.CanReviewClient)
                throw Forbidden();
            return;
        }

        var project = await projects.ReadProjectAsync(actor.Company, actor.Employee, projectId, ct);
        if (project is null || project.ClientId != clientId)
            throw Missing();
    }

    private async Task<SourceAccess> AccessAsync(Guid id, CancellationToken ct)
    {
        var actor = await GetActorAsync(ct);
        var source = await Sources.SingleOrDefaultAsync(s => s.Id == id && s.CompanyId == actor.Company && !s.Withdrawn, ct)
            ?? throw Missing();
        if (actor.Admin)
            return new SourceAccess(source, actor, true);
        if (source.ProjectId is null)
            return actor.CanReviewClient ? new SourceAccess(source, actor, true) : throw Missing();
        var role = await db.EmployeeProjects.AsNoTracking().Where(x => x.CompanyId == actor.Company
                && x.ProjectId == source.ProjectId && x.EmployeeId == actor.Employee)
            .Select(x => x.Role).SingleOrDefaultAsync(ct) ?? throw Missing();
        return new SourceAccess(source, actor, role.ToUpperInvariant() is "PO" or "PM" or "PRODUCTOWNER" or "PROJECTMANAGER");
    }

    private async Task<KnowledgeSourceVersion> VersionAsync(Guid id, int number, CancellationToken ct) =>
        await Versions.Include(x => x.Evidence).SingleOrDefaultAsync(x => x.SourceId == id && x.Number == number, ct)
        ?? throw Missing();

    private static KnowledgeSourceVersion BuildVersion(KnowledgeSource source, int number, string actor, string title,
        KnowledgeContent content, KnowledgeMeetingMode? meetingMode, DateTimeOffset? meetingAt)
    {
        if (string.IsNullOrWhiteSpace(title) || title.Length > 200)
            throw Invalid("A title of at most 200 characters is required.");
        if (source.Kind == KnowledgeSourceKind.MeetingNotes)
        {
            if (meetingMode is null || !Enum.IsDefined(meetingMode.Value) || meetingAt is null)
                throw Invalid("Choose Online or InPerson and supply the meeting date.");
        }
        else if (meetingMode is not null || meetingAt is not null)
        {
            throw Invalid("Meeting metadata is only valid for meeting notes.");
        }
        if (content.MediaType == "application/pdf" &&
            (content.Pdf is null || content.Pdf.Length > MaxPdfBytes || !content.Pdf.AsSpan().StartsWith("%PDF-"u8)))
            throw Invalid("A PDF upload must have a PDF signature and be at most 5 MiB.");
        if (content.MediaType != "application/pdf" &&
            (string.IsNullOrWhiteSpace(content.Text) || content.Text.Length > MaxTextLength))
            throw Invalid("Text is required and must be at most 256,000 characters.");

        return new KnowledgeSourceVersion
        {
            SourceId = source.Id, Number = number, Title = title.Trim(), CreatedByEmployeeId = actor,
            CreatedAtUtc = DateTime.UtcNow, Status = KnowledgeSourceStatus.PendingExtraction,
            MediaType = content.MediaType, Text = content.Text, Pdf = content.Pdf, FileName = content.FileName,
            MeetingMode = meetingMode, MeetingAtUtc = meetingAt?.ToUniversalTime()
        };
    }

    private void RecordPublication(KnowledgeSource source, int version, bool removed)
    {
        if (source.ProjectId is not string project)
            return;
        Changes.Add(new KnowledgePublicationChange
        {
            CompanyId = source.CompanyId, ProjectId = project, SourceId = source.Id, Version = version,
            Removed = removed, CreatedAtUtc = DateTime.UtcNow
        });
    }

    private static void Touch(KnowledgeSource source)
    {
        source.Revision++;
        source.UpdatedAtUtc = DateTime.UtcNow;
    }

    private async Task SaveAsync(CancellationToken ct)
    {
        try
        {
            if (db.Database.IsSqlServer() && db.ChangeTracker.Entries<KnowledgePublicationChange>()
                .Any(change => change.State == EntityState.Added))
            {
                // A cursor may advance only past committed changes. Hold the lock before the ID is allocated.
                await using var transaction = await db.Database.BeginTransactionAsync(ct);
                await db.Database.ExecuteSqlRawAsync("""
                    DECLARE @result int;
                    EXEC @result = sp_getapplock @Resource = 'SynTrace.KnowledgePublication',
                        @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
                    IF @result < 0 THROW 51000, 'Knowledge publication is busy.', 1;
                    """, ct);
                await db.SaveChangesAsync(ct);
                await transaction.CommitAsync(ct);
                return;
            }
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException) { throw Conflict(); }
        catch (DbUpdateException ex) when (ex.GetBaseException() is Microsoft.Data.SqlClient.SqlException { Number: 2601 or 2627 })
        {
            throw Conflict();
        }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 51000) { throw Conflict(); }
    }

    private static KnowledgeSourceSummary Summary(KnowledgeSource s, KnowledgeSourceVersion v) =>
        new(s.Id, s.ClientId, s.ProjectId, s.Kind, v.Title, v.Number, s.PublishedVersion, v.Status);

    private static KnowledgeSourceView View(KnowledgeSource s, KnowledgeSourceVersion v, bool canEdit) =>
        new(Summary(s, v), v.MeetingMode, v.MeetingAtUtc, v.FileName, canEdit ? v.Text : null,
            v.Evidence.Where(e => canEdit || e.Decision == KnowledgeEvidenceDecision.Approved)
                .OrderBy(e => e.QuoteOffset).ThenBy(e => e.Id)
                .Select(e => new KnowledgeEvidenceView(e.Id, e.Kind, e.Text, e.Quote, e.QuoteOffset, e.Decision)).ToArray(),
            canEdit ? v.FailureCode : null);

    private static KnowledgeSourceException Conflict() => new(StatusCodes.Status409Conflict,
        "This source version or status changed. Refresh and retry.");
    private static KnowledgeSourceException Invalid(string message) => new(StatusCodes.Status400BadRequest, message);
    private static KnowledgeSourceException Missing() => new(StatusCodes.Status404NotFound,
        "The source, client, or project was not found.");
    private static KnowledgeSourceException Forbidden() => new(StatusCodes.Status403Forbidden,
        "Your current permissions do not allow this change.");
}
