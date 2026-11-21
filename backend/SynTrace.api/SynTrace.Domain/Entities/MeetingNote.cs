using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Domain.Enums;

namespace SynTrace.Domain.Entities
{
    public class MeetingNote : ITenantOwned
    {
        public string MeetingNoteId { get; set; } = Guid.NewGuid().ToString();
        public string MeetingTitle { get; set; }
        public string Content { get; set; }
        public MeetingType MeetingType { get; set; }
        public DateTime MeetingDate { get; set; }
        public string CreatedBy { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;


        public string CompanyId { get; set; } = null!;
        public Company Company { get; set; } = null!;
        public string ClientId { get; set; } = null!;
        public Client Client { get; set; } = null!;
        public string? ProjectId { get; set; }
        public Project? Project { get; set; }

    }
}
