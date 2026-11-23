using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using SynTrace.Application.Behaviors;
using SynTrace.Application.Exceptions;

namespace SynTrace.Api.Errors;

public sealed class ApiExceptionHandler(ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context, Exception exception, CancellationToken cancellationToken)
    {
        var problem = exception switch
        {
            RequestValidationException invalid => new HttpValidationProblemDetails(
                new Dictionary<string, string[]>(invalid.Errors)) { Status = 400 },
            ValidationException => new ProblemDetails { Status = 400, Title = "Invalid request" },
            RequestFailureException expected => new ProblemDetails { Status = expected.StatusCode, Title = expected.Message },
            Microsoft.EntityFrameworkCore.DbUpdateConcurrencyException => new ProblemDetails
                { Status = 409, Title = "Conversation changed; refresh and retry" },
            Microsoft.EntityFrameworkCore.DbUpdateException e
                when e.InnerException is Microsoft.Data.SqlClient.SqlException { Number: 2601 or 2627 } sql &&
                     sql.Message.Contains("IX_ConversationMessages_ConversationId_SequenceNumber",
                         StringComparison.OrdinalIgnoreCase)
                => new ProblemDetails { Status = 409, Title = "Conversation changed; refresh and retry" },
            KeyNotFoundException => new ProblemDetails { Status = 404, Title = "Resource not found" },
            UnauthorizedAccessException => new ProblemDetails { Status = 403, Title = "Access denied" },
            _ => new ProblemDetails { Status = 500, Title = "An unexpected error occurred" }
        };
        if (problem.Status == 500)
            logger.LogError("Unhandled API failure {ExceptionType} ({TraceId})",
                exception.GetType().Name, context.TraceIdentifier);
        problem.Extensions["traceId"] = context.TraceIdentifier;
        context.Response.StatusCode = problem.Status ?? 500;
        await context.Response.WriteAsJsonAsync(problem, options: null,
            contentType: "application/problem+json", cancellationToken);
        return true;
    }
}
