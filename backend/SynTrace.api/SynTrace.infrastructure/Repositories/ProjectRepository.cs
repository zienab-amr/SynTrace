using System;
using System.Collections.Generic;
using System.ComponentModel.Design;
using System.Text;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.DTOs.Requests;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories
{
    public class ProjectRepository
    {
        private readonly SynTraceDbContext _db;
        private readonly ICurrentTenant _currentTenant;

        public ProjectRepository(
            SynTraceDbContext db,
            ICurrentTenant currentTenant
        )
        {
            _db = db;
            _currentTenant = currentTenant;
        }
        public async Task<Project?> GetProjectByIdAsync(string projectId, CancellationToken cancellationToken)
        {
            return await _db.Projects.FirstOrDefaultAsync(p => p.ProjectId == projectId,cancellationToken);
        }

        public async Task<List<Project>> GetAllProjectsAsync(CancellationToken cancellationToken)
        {
            return await _db.Projects.ToListAsync(cancellationToken);
        }

        public async Task<Project> CreateProjectAsync(ProjectRequestDTO request, CancellationToken cancellationToken)
        {
            var project = new Project
            {
                ProjectName = request.ProjectName,
                Description = request.Description,
                ProjectStatus = request.ProjectStatus,

                JiraProjectId = request.JiraProjectId,
                ClientId = request.ClientId,
                CompanyId = _currentTenant.CompanyId

            };

            await _db.Projects.AddAsync(project, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);

            return project;
        }

        public async Task<Project> UpdateProjectAsync(string projectId, ProjectRequestDTO request, CancellationToken cancellationToken)
        {
            var project = await GetProjectByIdAsync(projectId, cancellationToken);

            if(project == null)
            {
                throw new Exception($"Project not found.");
            }

            project.ProjectName = request.ProjectName;
            project.ProjectStatus = request.ProjectStatus;
            project.Description = request.Description;
            project.JiraProjectId = request.JiraProjectId;
            project.ClientId = request.ClientId;
            project.CompanyId = _currentTenant.CompanyId;

            await _db.SaveChangesAsync(cancellationToken);
            return project;
        }
    }
}
