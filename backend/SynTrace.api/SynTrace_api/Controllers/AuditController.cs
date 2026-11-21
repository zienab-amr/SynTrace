using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities.Audit;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Controllers;

[ApiController]
[Route("api/audit")]
[Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
public sealed class AuditController(SynTraceDbContext db, ICurrentTenant tenant) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] long? beforeId, [FromQuery, Range(1, 100)] int limit = 30,
        CancellationToken ct = default)
    {
        var company = tenant.CompanyId;
        var entries = await db.Set<ApiAuditEntry>().AsNoTracking()
            .Where(x => x.CompanyId == company && (!beforeId.HasValue || x.Id < beforeId.Value))
            .OrderByDescending(x => x.Id).Take(limit + 1)
            .Select(x => new { x.Id, x.EmployeeId, x.Operation, x.StatusCode, x.OccurredAtUtc })
            .ToListAsync(ct);
        return Ok(new { items = entries.Take(limit), nextBeforeId = entries.Count > limit ? entries[limit - 1].Id : (long?)null });
    }
}
