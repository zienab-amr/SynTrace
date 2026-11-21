using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace SynTrace.Infrastructure.Persistence.Context;

public sealed class SynTraceDesignTimeDbContextFactory : IDesignTimeDbContextFactory<SynTraceDbContext>
{
    public SynTraceDbContext CreateDbContext(string[] args)
    {
        // EF tooling can generate migrations/scripts without starting the API, Worker or RabbitMQ.
        // A database update still needs the real connection string supplied by the operator.
        var connection = Environment.GetEnvironmentVariable("ConnectionStrings__ConnectionDB");
        var options = new DbContextOptionsBuilder<SynTraceDbContext>()
            .UseSqlServer(connection ?? "Server=localhost;Database=SynTrace;Integrated Security=true;TrustServerCertificate=true")
            .Options;
        return new SynTraceDbContext(options);
    }
}
