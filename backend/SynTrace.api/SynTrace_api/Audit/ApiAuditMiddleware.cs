using System.Security.Claims;
using SynTrace.Domain.Entities.Audit;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Audit;

/// <summary>Records authenticated API writes using route templates and response status only.</summary>
public sealed class ApiAuditMiddleware(RequestDelegate next, ILogger<ApiAuditMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context, IServiceScopeFactory scopes)
    {
        var endpoint = context.GetEndpoint() as RouteEndpoint;
        var company = context.User.FindFirstValue("CompanyId");
        var employee = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        var method = context.Request.Method;
        var change = HttpMethods.IsPost(method) || HttpMethods.IsPut(method) || HttpMethods.IsPatch(method)
            || HttpMethods.IsDelete(method);
        var template = endpoint?.RoutePattern.RawText;
        await next(context);

        if (context.User.Identity?.IsAuthenticated != true || !change ||
            company is not { Length: > 0 and <= 450 } || employee is not { Length: > 0 and <= 450 } ||
            template is null || !template.StartsWith("api/", StringComparison.OrdinalIgnoreCase) ||
            template.StartsWith("api/assistant", StringComparison.OrdinalIgnoreCase))
            return;

        try
        {
            await using var scope = scopes.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<SynTraceDbContext>();
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
            var operation = $"{method} {template}";
            db.Set<ApiAuditEntry>().Add(new ApiAuditEntry
            {
                CompanyId = company,
                EmployeeId = employee,
                Operation = operation[..Math.Min(operation.Length, 220)],
                StatusCode = context.Response.StatusCode,
                OccurredAtUtc = DateTimeOffset.UtcNow
            });
            await db.SaveChangesAsync(timeout.Token);
        }
        catch (Exception error)
        {
            // Report audit storage issues independently from an operation that may already be committed.
            logger.LogError("API audit entry could not be written ({ErrorType}).", error.GetType().Name);
        }
    }
}
