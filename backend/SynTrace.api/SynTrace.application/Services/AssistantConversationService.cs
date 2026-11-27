using System.Text.Json;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Assistant;
using SynTrace.Application.Contracts.Repositories;
using SynTrace.Application.DTOs.Responses;
using SynTrace.Application.Exceptions;
using SynTrace.Domain.Entities;

namespace SynTrace.Application.Services;

/// <summary>
/// Persist pending turns BEFORE calling AI; store is just a single-instance cancellation
/// coordinator. SQL is the source of truth for ownership, status and correlation.
/// </summary>
public sealed class AssistantConversationService(
    IConversationRepository repository,
    IUnitOfWork unitOfWork,
    ICurrentTenant tenant,
    ICurrentEmployee employee,
    IAssistantAccessContextProvider accessProvider,
    IAssistantClient assistant,
    PendingAssistantTurnStore pendingTurns) : IAssistantConversationService
{
    private const int MaxQuestionLength = 2000;
    private const int MaxPendingQuestions = 6;
    private const int MaxQuotedExcerpts = 5;
    private const int MaxQuotedExcerptLength = 1000;
    private const int MaxTotalQuotedCharacters = 4000;

    public async Task<AssistantAskResponseDTO> AskAsync(
        string question, string? conversationId, string? editedMessageId,
        string? appendToMessageId, string? clientMessageId,
        IReadOnlyList<string>? quotedExcerpts, CancellationToken ct)
    {
        question = question?.Trim() ?? string.Empty;
        if (question.Length is < 1 or > MaxQuestionLength)
            throw new RequestFailureException(400, "Question must contain 1-2000 characters.");
        if (conversationId is not null && string.IsNullOrWhiteSpace(conversationId))
            throw new RequestFailureException(400, "conversationId cannot be empty.");
        if (editedMessageId is not null && !Guid.TryParse(editedMessageId, out _))
            throw new RequestFailureException(400, "editedMessageId must be a UUID.");
        if (editedMessageId is not null && (conversationId is null || appendToMessageId is not null))
            throw new RequestFailureException(400, "Edit requires conversationId and cannot be combined with append.");
        if (clientMessageId is not null && !Guid.TryParse(clientMessageId, out _))
            throw new RequestFailureException(400, "clientMessageId must be a UUID.");
        if (appendToMessageId is not null && !Guid.TryParse(appendToMessageId, out _))
            throw new RequestFailureException(400, "appendToMessageId must be a UUID.");
        // Pre-existing callers still work; Flutter should always send its own UUID.
        clientMessageId = clientMessageId is null ? Guid.NewGuid().ToString("D")
            : Guid.Parse(clientMessageId).ToString("D");
        appendToMessageId = appendToMessageId is null ? null : Guid.Parse(appendToMessageId).ToString("D");
        var quotes = ValidateQuotes(quotedExcerpts);
        // The first pending row, and each append mutation, must survive a browser CancelToken.
        // Limit the independent registration work; AI work still honors the request token.
        using var registrationTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var persistCt = registrationTimeout.Token;

        var companyId = tenant.CompanyId;
        var employeeId = employee.EmployeeId;
        PendingAssistantTurn? pending = null;
        ConversationMessage? message = null;
        Conversation? conversation = null;
        ConversationMessage? edited = null;
        IReadOnlyList<string> questions = [question];
        string correlation = Guid.NewGuid().ToString("N");
        long revision = 0;
        CancellationToken currentGenerationToken = CancellationToken.None;
        string? supersededCorrelation = null;
        var isAppend = false;

        // Resolve a referenced root by (company, employee, client id), not by an arbitrary
        // Flutter-provided conversationId. The database row may be pending or answered.
        if (appendToMessageId is not null)
        {
            pending = pendingTurns.Find(companyId, employeeId, appendToMessageId);
            if (pending is not null)
            {
                await pending.Gate.WaitAsync(persistCt);
                try
                {
                    // Root creates the pending row under the same gate before starting AI.
                    message = await repository.GetMessageByClientMessageIdAsync(appendToMessageId, persistCt);
                    if (message is not null)
                    {
                        conversation = await repository.GetConversationByIdAsync(message.ConversationId, persistCt);
                        if (conversation is null ||
                            (conversationId is not null && conversation.Id != conversationId))
                            throw new RequestFailureException(404, "Conversation not found.");
                        if (message.Status == "pending" && !pending.Completed && !pending.Failed)
                        {
                            if (pending.Questions.Count >= MaxPendingQuestions)
                                throw new RequestFailureException(400, "Too many appended messages.");
                            quotes = ValidateQuotes(pending.QuotedExcerpts.Concat(quotes));
                            supersededCorrelation = message.CorrelationId;
                            correlation = Guid.NewGuid().ToString("N");
                            pending.ActiveCancellation.Cancel();
                            pending.ActiveCancellation = new CancellationTokenSource();
                            pending.CorrelationId = correlation;
                            pending.Questions.Add(question);
                            pending.QuotedExcerpts.Clear();
                            pending.QuotedExcerpts.AddRange(quotes);
                            pending.Revision++;
                            pending.LastTouchedUtc = DateTime.UtcNow;
                            revision = pending.Revision;
                            currentGenerationToken = pending.ActiveCancellation.Token;
                            questions = pending.Questions.ToArray();
                            message.Question = string.Join("\n", questions);
                            message.CorrelationId = correlation;
                            conversation.UpdatedAt = DateTime.UtcNow;
                            try { await unitOfWork.SaveChangesAsync(persistCt); }
                            catch (ConversationConcurrencyException)
                            {
                                pending.Failed = true;
                                throw new RequestFailureException(409, "Conversation changed during append.");
                            }
                            isAppend = true;
                        }
                    }
                }
                finally { pending.Gate.Release(); }
            }
            else
            {
                // Recovery after a restart: the pending DB record is authoritative,
                // but process-local HTTP cancellation cannot be recovered.
                message = await repository.GetMessageByClientMessageIdAsync(appendToMessageId, persistCt);
                if (message is not null)
                {
                    conversation = await repository.GetConversationByIdAsync(message.ConversationId, persistCt);
                    if (conversation is null ||
                        (conversationId is not null && conversation.Id != conversationId))
                        throw new RequestFailureException(404, "Conversation not found.");
                    if (message.Status == "pending")
                    {
                        var original = message.Question;
                        pending = pendingTurns.Create(companyId, employeeId, appendToMessageId,
                            conversation.Id, false, null, original, quotes);
                        pending.CorrelationId = message.CorrelationId ?? correlation;
                        await pending.Gate.WaitAsync(persistCt);
                        try
                        {
                            supersededCorrelation = pending.CorrelationId;
                            pending.Questions.Add(question);
                            pending.Revision++;
                            correlation = Guid.NewGuid().ToString("N");
                            pending.CorrelationId = correlation;
                            pending.ActiveCancellation = new CancellationTokenSource();
                            currentGenerationToken = pending.ActiveCancellation.Token;
                            revision = pending.Revision;
                            questions = pending.Questions.ToArray();
                            message.Question = string.Join("\n", questions);
                            message.CorrelationId = correlation;
                            conversation.UpdatedAt = DateTime.UtcNow;
                            try { await unitOfWork.SaveChangesAsync(persistCt); }
                            catch (ConversationConcurrencyException)
                            {
                                pending.Failed = true;
                                throw new RequestFailureException(409, "Conversation changed during append.");
                            }
                            isAppend = true;
                        }
                        finally { pending.Gate.Release(); }
                    }
                }
            }
            if (!isAppend)
            {
                // If the first answer completed already, ignore append and create a new turn.
                conversationId = message?.ConversationId ?? conversationId;
                pending = null;
                message = null;
                conversation = null;
            }
        }

        if (!isAppend)
        {
            if (conversationId is not null)
                conversation = await repository.GetConversationByIdAsync(conversationId, persistCt)
                    ?? throw new RequestFailureException(404, "Conversation not found.");

            if (editedMessageId is not null)
            {
                edited = await repository.GetMessageByIdAsync(conversation!.Id, editedMessageId, persistCt)
                    ?? throw new RequestFailureException(404, "Message not found.");
                if (edited.Status != "answered")
                    throw new RequestFailureException(409, "Only answered messages can be edited.");
            }

            // New chat gets its permanent conversationId before the AI call.
            var chatId = conversation?.Id ?? Guid.NewGuid().ToString();
            pending = pendingTurns.Create(companyId, employeeId, clientMessageId, chatId,
                conversation is null, editedMessageId, question, quotes);
            correlation = pending.CorrelationId;
            currentGenerationToken = pending.ActiveCancellation.Token;
            revision = pending.Revision;

            await pending.Gate.WaitAsync(persistCt);
            try
            {
                var now = DateTime.UtcNow;
                if (conversation is null)
                {
                    conversation = new Conversation
                    {
                        Id = chatId, CompanyId = companyId, EmployeeId = employeeId,
                        Title = question.Length > 100 ? question[..100] : question,
                        CreatedAt = now, UpdatedAt = now, NextSequenceNumber = 1
                    };
                    await repository.AddConversationAsync(conversation, persistCt);
                }
                var sequence = conversation.NextSequenceNumber;
                conversation.NextSequenceNumber = checked(sequence + 1);
                conversation.UpdatedAt = now;
                message = new ConversationMessage
                {
                    ConversationId = chatId,
                    ClientMessageId = clientMessageId,
                    CorrelationId = correlation,
                    Question = question,
                    Answer = string.Empty, // NOT NULL; populated after the AI responds
                    Status = "pending",
                    SequenceNumber = sequence,
                    CreatedAt = now
                };
                await repository.AddMessageAsync(message, persistCt);
                await unitOfWork.SaveChangesAsync(persistCt); // Pending row exists BEFORE calling AI.
            }
            catch (ConversationConcurrencyException)
            {
                pending.Failed = true;
                throw new RequestFailureException(409, "Conversation changed while starting the request.");
            }
            catch
            {
                pending.Failed = true;
                throw;
            }
            finally { pending.Gate.Release(); }
        }

        // This scope is owner-checked. History excludes the pending root, plus anything
        // at/after the edited turn. It contains only answered turns, oldest first.
        if (!string.IsNullOrWhiteSpace(supersededCorrelation))
            await assistant.CancelAsync(supersededCorrelation, CancellationToken.None);

        var chat = conversation!;
        var root = message!;
        if (isAppend && pending!.EditedMessageId is not null)
        {
            edited = await repository.GetMessageByIdAsync(chat.Id, pending.EditedMessageId, ct)
                ?? throw new RequestFailureException(404, "Edited message no longer exists.");
        }
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(ct, currentGenerationToken);
        try
        {
            var access = await accessProvider.GetForCurrentEmployeeAsync(companyId, employeeId, linked.Token);
            if (!access.HasAccessibleProjects)
                throw new RequestFailureException(403, "No accessible projects are available for this assistant.");

            var history = edited is null
                ? await repository.GetLastMessagesAsync(chat.Id, access.HistoryCount, linked.Token)
                : await repository.GetLastMessagesBeforeSequenceAsync(chat.Id, edited.SequenceNumber, access.HistoryCount, linked.Token);
            var turns = history.Select(m => new AssistantHistoryTurn(
                Truncate(m.Question, MaxQuestionLength), Truncate(m.Answer, 8000))).ToArray();

            var result = await assistant.AskAsync(questions[^1], companyId, employeeId, access.Scope,
                correlation, access.JiraAccountId, chat.Id, turns, questions.Take(questions.Count - 1).ToArray(),
                quotes, clearAiMemory: turns.Length == 0, cancellationToken: linked.Token);

            linked.Token.ThrowIfCancellationRequested();
            if (result.Failure != AssistantFailure.None || result.Answer is null)
                throw result.Failure switch
                {
                    AssistantFailure.Cancelled => new RequestFailureException(409, "AI request cancelled."),
                    AssistantFailure.BadRequest => new RequestFailureException(400, "Question rejected by the AI service."),
                    AssistantFailure.Misconfigured => new RequestFailureException(500, "AI service is not configured."),
                    _ => new RequestFailureException(503, "AI service is unavailable.")
                };

            await pending!.Gate.WaitAsync(linked.Token);
            try
            {
                linked.Token.ThrowIfCancellationRequested();
                if (pending.Revision != revision || pending.Completed || pending.Failed ||
                    root.Status != "pending" || root.CorrelationId != correlation)
                    throw new OperationCanceledException("Superseded AI result", linked.Token);
                var now = DateTime.UtcNow;
                root.Answer = result.Answer.Answer;
                root.Status = "answered";
                root.LinksJson = JsonSerializer.Serialize(result.Answer.Links ?? []);
                // If editing, delete the old tail ONLY with the successful replacement,
                // within the same SaveChanges transaction. Never delete the pending root.
                if (edited is not null)
                {
                    var suffix = await repository.GetMessagesFromSequenceAsync(chat.Id, edited.SequenceNumber, linked.Token);
                    repository.RemoveMessages(suffix.Where(m => m.ConversationMessageId != root.ConversationMessageId));
                }
                chat.UpdatedAt = now; // RowVersion protects against writes during the AI call.
                await unitOfWork.SaveChangesAsync(linked.Token);
                pending.Completed = true;
                pending.LastTouchedUtc = now;
                pendingTurns.Discard(pending);
                return new AssistantAskResponseDTO(chat.Id, root.ConversationMessageId,
                    result.Answer.Status, result.Answer.Answer, result.Answer.Links ?? [], correlation);
            }
            finally { pending!.Gate.Release(); }
        }
        catch (OperationCanceledException) when (linked.IsCancellationRequested)
        {
            await assistant.CancelAsync(correlation, CancellationToken.None);
            // Pending row intentionally remains pending: an incoming append may already
            // be racing to replace its correlation; no obsolete answer can be committed.
            throw;
        }
        catch (ConversationConcurrencyException)
        {
            // Underlying SaveChanges rolls back; reply 409, never commit a stale answer.
            throw new RequestFailureException(409, "Conversation changed. Refresh the chat and try again.");
        }
        catch (RequestFailureException)
        {
            // Do not overwrite a newer append's record when our AI attempt fails.
            await MarkFailedIfLatestAsync(pending!, root, chat, correlation, revision);
            throw;
        }
    }

    private async Task MarkFailedIfLatestAsync(PendingAssistantTurn pending, ConversationMessage root,
        Conversation chat, string correlation, long revision)
    {
        await pending.Gate.WaitAsync();
        try
        {
            if (pending.Revision != revision || pending.Completed || root.CorrelationId != correlation)
                return;
            root.Status = "failed";
            chat.UpdatedAt = DateTime.UtcNow;
            pending.Failed = true;
            try { await unitOfWork.SaveChangesAsync(CancellationToken.None); }
            catch (ConversationConcurrencyException) { /* A newer request owns this turn. */ }
        }
        finally { pending.Gate.Release(); }
    }

    private static string Truncate(string input, int max) => input.Length <= max ? input : input[..max];

    private static IReadOnlyList<string> ValidateQuotes(IEnumerable<string>? input)
    {
        var quotes = (input ?? []).Select(q => q?.Trim() ?? "").Distinct(StringComparer.Ordinal).ToArray();
        if (quotes.Length > MaxQuotedExcerpts ||
            quotes.Any(q => q.Length is < 1 or > MaxQuotedExcerptLength) ||
            quotes.Sum(q => q.Length) > MaxTotalQuotedCharacters)
            throw new RequestFailureException(400, "quotedExcerpts exceed supported limits.");
        return quotes;
    }
}
