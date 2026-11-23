namespace SynTrace.Application.Exceptions;

public sealed class ConversationConcurrencyException(string message, Exception? inner = null)
    : Exception(message, inner);
