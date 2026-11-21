using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Entities
{
    public class Project : ITenantOwned
    {
        public string ProjectId { get; set; } = Guid.NewGuid().ToString();
        public string ProjectName { get; set; } = null!;
        public string? Description { get; set; }
        public ProjectStatus ProjectStatus { get; set; } = ProjectStatus.NotStarted;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public string? JiraProjectId { get; set; } = null!;
        public JiraProject? JiraProject { get; set; } = null!;
        public string ClientId { get; set; }
        public Client Client { get; set; } = null!;
        public string CompanyId { get; set; }
        public Company Company { get; set; } = null!;

        public ICollection<MeetingNote> MeetingNotes { get; set; } = new List<MeetingNote>();
        public ICollection<EmployeeProject> EmployeeProjects { get; set; } = new List<EmployeeProject>();

        //b3den ahot hena github repos --------->
    }
}
