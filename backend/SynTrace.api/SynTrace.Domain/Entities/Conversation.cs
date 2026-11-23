using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities
{
    public class Conversation : ITenantOwned
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();

        public string CompanyId { get; set; } = null!;
        public string EmployeeId { get; set; } = null!;

        public string Title { get; set; } = null!;

        public long NextSequenceNumber { get; set; } = 1;

        public byte[] RowVersion { get; set; } = null!;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<ConversationMessage> Messages { get; set; } = new List<ConversationMessage>();
    }
}
