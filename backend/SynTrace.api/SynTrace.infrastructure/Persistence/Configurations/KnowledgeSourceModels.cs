using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Knowledge;

namespace SynTrace.Infrastructure.Persistence.Configurations;

internal sealed class KnowledgeSourceModel : IEntityTypeConfiguration<KnowledgeSource>
{
    public void Configure(EntityTypeBuilder<KnowledgeSource> entity)
    {
        entity.ToTable("KnowledgeSources");
        entity.HasKey(x => x.Id);
        entity.Property(x => x.Id).ValueGeneratedNever();
        entity.Property(x => x.CompanyId).HasMaxLength(450);
        entity.Property(x => x.ClientId).HasMaxLength(450);
        entity.Property(x => x.ProjectId).HasMaxLength(450);
        entity.Property(x => x.CreatedByEmployeeId).HasMaxLength(450);
        entity.Property(x => x.Revision).IsConcurrencyToken();
        entity.HasIndex(x => new { x.CompanyId, x.ProjectId });
        entity.HasIndex(x => new { x.CompanyId, x.ClientId });
        entity.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);
        entity.HasOne<Client>().WithMany().HasForeignKey(x => x.ClientId).OnDelete(DeleteBehavior.NoAction);
        entity.HasOne<Project>().WithMany().HasForeignKey(x => x.ProjectId).OnDelete(DeleteBehavior.NoAction);
    }
}

internal sealed class KnowledgeSourceVersionModel : IEntityTypeConfiguration<KnowledgeSourceVersion>
{
    public void Configure(EntityTypeBuilder<KnowledgeSourceVersion> entity)
    {
        entity.ToTable("KnowledgeSourceVersions");
        entity.HasKey(x => new { x.SourceId, x.Number });
        entity.Property(x => x.Title).HasMaxLength(200);
        entity.Property(x => x.FileName).HasMaxLength(200);
        entity.Property(x => x.MediaType).HasMaxLength(60);
        entity.Property(x => x.FailureCode).HasMaxLength(30);
        entity.Property(x => x.CreatedByEmployeeId).HasMaxLength(450);
        entity.Property(x => x.ReviewedByEmployeeId).HasMaxLength(450);
        entity.HasOne<KnowledgeSource>().WithMany().HasForeignKey(x => x.SourceId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class KnowledgeEvidenceModel : IEntityTypeConfiguration<KnowledgeEvidence>
{
    public void Configure(EntityTypeBuilder<KnowledgeEvidence> entity)
    {
        entity.ToTable("KnowledgeEvidence");
        entity.HasKey(x => x.Id);
        entity.Property(x => x.Id).ValueGeneratedNever();
        entity.Property(x => x.Text).HasMaxLength(2000);
        entity.Property(x => x.Quote).HasMaxLength(4000);
        entity.HasOne<KnowledgeSourceVersion>().WithMany(x => x.Evidence)
            .HasForeignKey(x => new { x.SourceId, Number = x.Version }).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class KnowledgePublicationChangeModel : IEntityTypeConfiguration<KnowledgePublicationChange>
{
    public void Configure(EntityTypeBuilder<KnowledgePublicationChange> entity)
    {
        entity.ToTable("KnowledgePublicationChanges");
        entity.HasKey(x => x.Id);
        entity.Property(x => x.CompanyId).HasMaxLength(450);
        entity.Property(x => x.ProjectId).HasMaxLength(450);
        entity.HasIndex(x => new { x.CompanyId, x.Id });
    }
}
