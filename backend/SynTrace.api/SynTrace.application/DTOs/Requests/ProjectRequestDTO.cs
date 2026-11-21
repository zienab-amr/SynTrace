using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Enums;

namespace SynTrace.Application.DTOs.Requests
{
    public class ProjectRequestDTO
    {
        public string ProjectName { get; set; } = null!;
        public string? Description { get; set; }
        public ProjectStatus ProjectStatus { get; set; } = ProjectStatus.NotStarted;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public string? JiraProjectId { get; set; } = null!;
        public string ClientId { get; set; }
        public string CompanyId { get; set; }
    }
}
