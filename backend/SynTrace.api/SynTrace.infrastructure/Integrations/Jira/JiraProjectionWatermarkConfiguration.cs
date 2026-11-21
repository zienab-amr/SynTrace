using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SynTrace.Domain.Entities;

namespace SynTrace.Infrastructure.Integrations.Jira;

public sealed class JiraProjectionWatermarkConfiguration : IEntityTypeConfiguration<JiraProjectionWatermark>
{
    public void Configure(EntityTypeBuilder<JiraProjectionWatermark> builder)
    {
        builder.ToTable("JiraProjectionWatermarks");
        builder.HasKey(x => new { x.JiraConnectionId, x.Kind, x.ExternalId }).IsClustered(false);
        builder.Property(x => x.JiraConnectionId).HasMaxLength(256);
        builder.Property(x => x.CompanyId).HasMaxLength(450);
        builder.Property(x => x.ExternalId).HasMaxLength(64);
    }
}
