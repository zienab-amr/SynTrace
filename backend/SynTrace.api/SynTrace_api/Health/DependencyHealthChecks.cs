using Microsoft.Extensions.Diagnostics.HealthChecks;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Api.Health;

public sealed class SqlServerHealthCheck(SynTraceDbContext db) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken) =>
        await db.Database.CanConnectAsync(cancellationToken)
            ? HealthCheckResult.Healthy()
            : HealthCheckResult.Unhealthy("SQL Server is unavailable.");
}

public sealed class RabbitMqHealthCheck(RabbitMqConnectionProvider rabbit) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken) =>
        (await rabbit.GetConnectionAsync(cancellationToken)).IsOpen
            ? HealthCheckResult.Healthy()
            : HealthCheckResult.Unhealthy("RabbitMQ is unavailable.");
}
