using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Repositories;
using SynTrace.Domain.Entities;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Repositories;

public sealed class ConversationRepository(
    SynTraceDbContext db, ICurrentEmployee employee, ICurrentTenant tenant) : IConversationRepository
{
    public Task AddConversationAsync(Conversation conversation, CancellationToken ct)
        => db.Conversations.AddAsync(conversation, ct).AsTask();

    // Deliberately tracked: a single DbContext holds the original RowVersion across an AI call.
    public Task<Conversation?> GetConversationByIdAsync(string conversationId, CancellationToken ct)
        => db.Conversations.FirstOrDefaultAsync(c =>
            c.Id == conversationId && c.CompanyId == tenant.CompanyId &&
            c.EmployeeId == employee.EmployeeId, ct);

    public Task<List<Conversation>> GetEmployeeConversationsAsync(CancellationToken ct)
        => db.Conversations.AsNoTracking()
            .Where(c => c.CompanyId == tenant.CompanyId && c.EmployeeId == employee.EmployeeId)
            .OrderByDescending(c => c.UpdatedAt).ThenByDescending(c => c.Id)
            .ToListAsync(ct);

    public Task<Dictionary<string, string?>> GetEmployeeConversationPreviewsAsync(CancellationToken ct)
        => GetPreviewsAsync(ct);

    private async Task<Dictionary<string, string?>> GetPreviewsAsync(CancellationToken ct)
    {
        // Correlated subquery, one roundtrip. Avoid loading every message for the drawer.
        var rows = await db.Conversations.AsNoTracking()
            .Where(c => c.CompanyId == tenant.CompanyId && c.EmployeeId == employee.EmployeeId)
            .Select(c => new
            {
                c.Id,
                Preview = c.Messages.Where(m => m.Status == "answered")
                    .OrderByDescending(m => m.SequenceNumber)
                    .Select(m => m.Answer).FirstOrDefault()
            }).ToListAsync(ct);
        return rows.ToDictionary(r => r.Id, r => r.Preview);
    }

    private IQueryable<ConversationMessage> OwnedMessages(string conversationId) =>
        db.ConversationMessages.Where(m =>
            m.ConversationId == conversationId &&
            m.Conversation.CompanyId == tenant.CompanyId &&
            m.Conversation.EmployeeId == employee.EmployeeId);

    public Task<ConversationMessage?> GetMessageByClientMessageIdAsync(string clientMessageId, CancellationToken ct)
        => db.ConversationMessages
            .Where(m => m.ClientMessageId == clientMessageId &&
                m.Conversation.CompanyId == tenant.CompanyId &&
                m.Conversation.EmployeeId == employee.EmployeeId)
            .FirstOrDefaultAsync(ct);

    public Task<List<ConversationMessage>> GetConversationMessagesAsync(string conversationId, CancellationToken ct)
        => OwnedMessages(conversationId).AsNoTracking()
            .OrderBy(m => m.SequenceNumber).ToListAsync(ct);

    public async Task<List<ConversationMessage>> GetLastMessagesAsync(string conversationId, int count, CancellationToken ct)
    {
        var messages = await OwnedMessages(conversationId).AsNoTracking()
            .Where(m => m.Status == "answered")
            .OrderByDescending(m => m.SequenceNumber).Take(count).ToListAsync(ct);
        messages.Reverse();
        return messages;
    }

    public async Task<List<ConversationMessage>> GetLastMessagesBeforeSequenceAsync(
        string conversationId, long beforeSequence, int count, CancellationToken ct)
    {
        var messages = await OwnedMessages(conversationId).AsNoTracking()
            .Where(m => m.Status == "answered" && m.SequenceNumber < beforeSequence)
            .OrderByDescending(m => m.SequenceNumber).Take(count).ToListAsync(ct);
        messages.Reverse();
        return messages;
    }

    public Task<ConversationMessage?> GetMessageByIdAsync(string conversationId, string messageId, CancellationToken ct)
        => OwnedMessages(conversationId).AsNoTracking()
            .FirstOrDefaultAsync(m => m.ConversationMessageId == messageId, ct);

    // Tracked messages can be marked for deletion together with the new message in one SaveChanges.
    public Task<List<ConversationMessage>> GetMessagesFromSequenceAsync(
        string conversationId, long sequenceNumber, CancellationToken ct)
        => OwnedMessages(conversationId)
            .Where(m => m.SequenceNumber >= sequenceNumber).ToListAsync(ct);

    public Task AddMessageAsync(ConversationMessage message, CancellationToken ct)
        => db.ConversationMessages.AddAsync(message, ct).AsTask();

    public void RemoveMessages(IEnumerable<ConversationMessage> messages)
        => db.ConversationMessages.RemoveRange(messages);

    public async Task<bool> RemoveConversationAsync(string conversationId, CancellationToken ct)
    {
        var conversation = await GetConversationByIdAsync(conversationId, ct);
        if (conversation is null) return false;
        db.Conversations.Remove(conversation);
        return true;
    }
}
