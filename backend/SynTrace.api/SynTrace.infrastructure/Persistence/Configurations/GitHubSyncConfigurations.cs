using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SynTrace.Domain.Entities.GitHub;

namespace SynTrace.Infrastructure.Persistence.Configurations;

public sealed class GitHubRepositorySyncConfiguration : IEntityTypeConfiguration<GitHubRepositorySync>
{
    public void Configure(EntityTypeBuilder<GitHubRepositorySync> entity)
    {
        entity.ToTable("GitHubRepositorySync");
        entity.HasKey(x => x.BindingId);
        entity.Property(x => x.BindingId).HasMaxLength(64);
        entity.Property(x => x.Phase).HasMaxLength(24);
        entity.Property(x => x.TargetHeadSha).HasMaxLength(64);
        entity.Property(x => x.LastIndexedHeadSha).HasMaxLength(64);
        entity.Property(x => x.LeaseToken).HasMaxLength(64);
        entity.Property(x => x.LastFailure).HasMaxLength(250);
        entity.HasIndex(x => new { x.Revoked, x.DueAtUtc });
    }
}

public sealed class GitHubSyncedItemConfiguration : IEntityTypeConfiguration<GitHubSyncedItem>
{
    public void Configure(EntityTypeBuilder<GitHubSyncedItem> entity)
    {
        entity.ToTable("GitHubSyncedItems");
        entity.HasKey(x => new { x.BindingId, x.Kind, x.EntityId });
        entity.Property(x => x.BindingId).HasMaxLength(64);
        entity.Property(x => x.Kind).HasMaxLength(24);
        entity.Property(x => x.EntityId).HasMaxLength(128);
    }
}

public sealed class GitHubDataOutboxConfiguration : IEntityTypeConfiguration<GitHubDataOutbox>
{
    public void Configure(EntityTypeBuilder<GitHubDataOutbox> entity)
    {
        entity.ToTable("GitHubDataOutbox");
        entity.HasKey(x => new { x.BindingId, x.SourceVersion });
        entity.Property(x => x.BindingId).HasMaxLength(64);
        entity.Property(x => x.EventType).HasMaxLength(64);
        entity.Property(x => x.EntityId).HasMaxLength(128);
        entity.Property(x => x.CompanyId).HasMaxLength(450);
        entity.Property(x => x.ProjectId).HasMaxLength(450);
        entity.HasIndex(x => x.OccurredAtUtc);
    }
}
