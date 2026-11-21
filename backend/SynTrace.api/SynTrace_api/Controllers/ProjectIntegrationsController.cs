using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Enums;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/projects")]
public sealed class ProjectIntegrationsController(
    SynTraceDbContext db, ICurrentTenant tenant, ICurrentEmployee employee,
    ProjectIntegrationAccess access) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List([FromQuery, Range(0, int.MaxValue)] int offset = 0, CancellationToken ct = default)
    {
        var companyId = tenant.CompanyId;
        var employeeId = employee.EmployeeId;
        var isAdmin = await access.IsCompanyAdminAsync(companyId, employeeId, ct);
        var projects = await db.Projects.AsNoTracking().Where(x => x.CompanyId == companyId &&
                (isAdmin || x.EmployeeProjects.Any(p => p.CompanyId == companyId && p.EmployeeId == employeeId)))
            .OrderBy(x => x.ProjectName).ThenBy(x => x.ProjectId).Skip(offset).Take(100)
            .Select(x => new { x.ProjectId, x.ProjectName, x.ClientId, x.Description, x.JiraProjectId }).ToListAsync(ct);
        return Ok(projects);
    }

    [HttpPost]
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    public async Task<IActionResult> Create(CreateProjectRequest request, CancellationToken ct)
    {
        var companyId = tenant.CompanyId;
        var name = request.Name.Trim();
        if (name.Length == 0)
            return BadRequest(new { message = "A project name is required." });
        if (!await db.Clients.AnyAsync(x => x.CompanyId == companyId && x.ClientId == request.ClientId, ct))
            return NotFound(new { message = "Client not found." });
        var project = new Project
        {
            CompanyId = companyId, ClientId = request.ClientId, ProjectName = name,
            Description = request.Description?.Trim()
        };
        db.Projects.Add(project);
        await db.SaveChangesAsync(ct);
        return StatusCode(StatusCodes.Status201Created, new { project.ProjectId, project.ProjectName, project.ClientId });
    }

    [HttpGet("{projectId}")]
    public async Task<IActionResult> Get(string projectId, CancellationToken ct)
    {
        var project = await access.ReadProjectAsync(tenant.CompanyId, employee.EmployeeId, projectId, ct);
        return project is null ? NotFound() : Ok(new
        {
            project.ProjectId, project.ProjectName, project.Description, project.ClientId, project.JiraProjectId,
            status = project.ProjectStatus
        });
    }

    [HttpPut("{projectId}")]
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    public async Task<IActionResult> Update(string projectId, UpdateProjectRequest request, CancellationToken ct)
    {
        var companyId = tenant.CompanyId;
        var name = request.Name.Trim();
        if (name.Length == 0)
            return BadRequest(new { message = "A project name is required." });
        var updated = await db.Projects.Where(x => x.CompanyId == companyId && x.ProjectId == projectId)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.ProjectName, name)
                .SetProperty(x => x.Description, request.Description)
                .SetProperty(x => x.ProjectStatus, request.Status), ct);
        return updated == 0 ? NotFound() : NoContent();
    }

    [HttpGet("jira-options")]
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    public async Task<IActionResult> JiraOptions([FromQuery, Range(0, int.MaxValue)] int offset = 0, CancellationToken ct = default)
    {
        var companyId = tenant.CompanyId;
        if (!await HasJiraConnectionAsync(companyId, ct))
            return Conflict(new { message = "Connect the company to Jira first." });
        return Ok(await db.JiraProjects.AsNoTracking().Where(x => x.CompanyId == companyId)
            .OrderBy(x => x.Key).ThenBy(x => x.Id).Skip(offset).Take(100)
            .Select(x => new { jiraProjectId = x.Id, x.Key, x.Name }).ToListAsync(ct));
    }

    [HttpPut("{projectId}/jira")]
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    public async Task<IActionResult> MapJira(string projectId, MapJiraRequest request, CancellationToken ct)
    {
        var companyId = tenant.CompanyId;
        if (request.JiraProjectId is not null && !await db.JiraProjects.AsNoTracking()
                .AnyAsync(x => x.Id == request.JiraProjectId && x.CompanyId == companyId, ct))
            return NotFound(new { message = "Jira project not found." });
        if (request.JiraProjectId is not null && !await HasJiraConnectionAsync(companyId, ct))
            return Conflict(new { message = "Connect the company to Jira first." });

        var updated = await db.Projects.Where(x => x.ProjectId == projectId && x.CompanyId == companyId)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.JiraProjectId, request.JiraProjectId), ct);
        return updated == 0 ? NotFound() : NoContent();
    }

    [HttpPut("{projectId}/members/{employeeId}")]
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    public async Task<IActionResult> AddMember(string projectId, string employeeId,
        [FromQuery] string role = "Member", CancellationToken ct = default)
    {
        var companyId = tenant.CompanyId;
        if (!await db.Projects.AnyAsync(x => x.ProjectId == projectId && x.CompanyId == companyId, ct)
            || !await db.Employees.AnyAsync(x => x.Id == employeeId && x.CompanyId == companyId, ct))
            return NotFound();
        if (role is not ("Member" or "ProductOwner" or "ProjectManager"))
            return BadRequest(new { message = "Use Member, ProductOwner or ProjectManager." });
        var membership = db.EmployeeProjects.Where(x => x.ProjectId == projectId &&
            x.CompanyId == companyId && x.EmployeeId == employeeId);
        if (await membership.ExecuteUpdateAsync(s => s.SetProperty(x => x.Role, role), ct) != 0)
            return NoContent();
        db.EmployeeProjects.Add(new EmployeeProject
        {
            CompanyId = companyId, ProjectId = projectId, EmployeeId = employeeId, Role = role
        });
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException ex) when (ex.GetBaseException() is Microsoft.Data.SqlClient.SqlException { Number: 2601 or 2627 })
        {
            await membership.ExecuteUpdateAsync(s => s.SetProperty(x => x.Role, role), ct);
        }
        return NoContent();
    }

    [HttpDelete("{projectId}/members/{employeeId}")]
    [Authorize(Policy = CurrentCompanyAdminHandler.Policy)]
    public async Task<IActionResult> RemoveMember(string projectId, string employeeId, CancellationToken ct)
    {
        var companyId = tenant.CompanyId;
        await db.EmployeeProjects.Where(x => x.ProjectId == projectId &&
            x.CompanyId == companyId && x.EmployeeId == employeeId).ExecuteDeleteAsync(ct);
        return NoContent();
    }

    private Task<bool> HasJiraConnectionAsync(string companyId, CancellationToken ct) =>
        db.JiraConnections.AnyAsync(x => x.CompanyId == companyId && x.status &&
            x.JiraConnectionType == JiraConnectionType.Company, ct);

    public sealed record CreateProjectRequest(
        [Required, StringLength(450)] string ClientId,
        [Required, StringLength(200)] string Name,
        [StringLength(4000)] string? Description);
    public sealed record UpdateProjectRequest(
        [Required, StringLength(200)] string Name,
        [StringLength(4000)] string? Description,
        [EnumDataType(typeof(ProjectStatus))] ProjectStatus Status);
    public sealed record MapJiraRequest([StringLength(450)] string? JiraProjectId);
}
