using System.Collections.Concurrent;

namespace SynTrace.Application.Services;

/// <summary>
/// Coordinates cancellation/append across HTTP requests. Pending turns ARE persisted in SQL;
/// this store only owns in-process cancellation tokens and request serialization.
/// Entries are scoped to authenticated company + employee.
/// SINGLE INSTANCE ONLY: use a distributed coordinator for multiple API replicas.
/// </summary>
public sealed class PendingAssistantTurnStore
{
    private readonly ConcurrentDictionary<PendingKey, PendingAssistantTurn> _turns = new();
    private static readonly TimeSpan Retention = TimeSpan.FromMinutes(5);
    private const int MaxEntries = 2000;

    public PendingAssistantTurn Create(string companyId, string employeeId, string rootClientMessageId,
        string conversationId, bool newConversation, string? editedMessageId, string question,
        IReadOnlyList<string>? quotedExcerpts = null)
    {
        EvictExpired();
        if (_turns.Count >= MaxEntries)
            throw new SynTrace.Application.Exceptions.RequestFailureException(429, "Too many pending assistant requests.");

        var key = new PendingKey(companyId, employeeId, rootClientMessageId);
        var turn = new PendingAssistantTurn(key, conversationId, newConversation, editedMessageId, question, quotedExcerpts);
        if (!_turns.TryAdd(key, turn))
            throw new SynTrace.Application.Exceptions.RequestFailureException(409, "This client message ID is already in use.");
        return turn;
    }

    public PendingAssistantTurn? Find(string companyId, string employeeId, string rootClientMessageId)
    {
        EvictExpired();
        var key = new PendingKey(companyId, employeeId, rootClientMessageId);
        return _turns.TryGetValue(key, out var turn) ? turn : null;
    }

    public void Discard(PendingAssistantTurn turn)
    {
        // Keep completed entries briefly, so an append that races with the first response
        // can resolve the conversation ID, even if Flutter cancelled the HTTP response.
        turn.LastTouchedUtc = DateTime.UtcNow;
    }

    private void EvictExpired()
    {
        var cutoff = DateTime.UtcNow - Retention;
        foreach (var pair in _turns)
        {
            if (pair.Value.LastTouchedUtc < cutoff)
                ((ICollection<KeyValuePair<PendingKey, PendingAssistantTurn>>)_turns).Remove(pair);
        }
    }
}

public readonly record struct PendingKey(string CompanyId, string EmployeeId, string ClientMessageId);

public sealed class PendingAssistantTurn(
    PendingKey key, string conversationId, bool newConversation, string? editedMessageId,
    string initialQuestion, IReadOnlyList<string>? initialQuotedExcerpts = null)
{
    // Gate serializes append with final database commit; no lock is held across the AI call.
    public SemaphoreSlim Gate { get; } = new(1, 1);
    public PendingKey Key { get; } = key;
    public string ConversationId { get; } = conversationId;
    public bool IsNewConversation { get; } = newConversation;
    public string? EditedMessageId { get; } = editedMessageId;
    public List<string> Questions { get; } = [initialQuestion];
    // Multiple quoted selections, retained across appends to the same unanswered turn.
    // Only accessed and mutated under Gate, like Questions.
    public List<string> QuotedExcerpts { get; } = initialQuotedExcerpts?.ToList() ?? [];
    public long Revision { get; set; } = 1;
    public string CorrelationId { get; set; } = Guid.NewGuid().ToString("N");
    public CancellationTokenSource ActiveCancellation { get; set; } = new();
    public bool Completed { get; set; }
    public bool Failed { get; set; }
    public DateTime LastTouchedUtc { get; set; } = DateTime.UtcNow;
}
