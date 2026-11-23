using System;
using System.Collections.Generic;
using System.Text;

namespace SynTrace.Domain.Entities
{
    public class ConversationMessage
    {
        public string ConversationMessageId { get; set; } = Guid.NewGuid().ToString();
        public string ConversationId { get; set; } = null!;
        // First unanswered Flutter bubble; subsequent appends use its id.
        public string? ClientMessageId { get; set; }
        // Most recent AI request for this turn, including while pending.
        public string? CorrelationId { get; set; }

        public string Question { get; set; } = null!;
        public string Answer { get; set; } = null!;

        public string Status { get; set; } = null!;
        public string? LinksJson { get; set; }

        public long SequenceNumber { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public Conversation Conversation { get; set; } = null!;

    }
}
