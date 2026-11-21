using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SynTrace.Domain.Entities.Audit;

namespace SynTrace.Infrastructure.Persistence.Configurations;

public sealed class ApiAuditEntryConfiguration : IEntityTypeConfiguration<ApiAuditEntry>
{
    public void Configure(EntityTypeBuilder<ApiAuditEntry> builder)
    {
        builder.ToTable("ApiAuditEntries");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.CompanyId).HasMaxLength(450);
        builder.Property(x => x.EmployeeId).HasMaxLength(450);
        builder.Property(x => x.Operation).HasMaxLength(220);
        builder.HasIndex(x => new { x.CompanyId, x.Id });
    }
}
