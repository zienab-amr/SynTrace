namespace SynTrace.Application.Exceptions;

public sealed class RequestFailureException(int statusCode, string message) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}
