using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SynTrace.Domain.Entities;

namespace SynTrace.Infrastructure.Persistence.Configurations;

public sealed class IdentityChallengeConfiguration : IEntityTypeConfiguration<IdentityChallenge>
{
    public void Configure(EntityTypeBuilder<IdentityChallenge> builder)
    {
        builder.ToTable("IdentityChallenges");
        builder.HasKey(x => x.Key);
        builder.Property(x => x.Key).HasMaxLength(64).IsUnicode(false);
        builder.Property(x => x.SubjectId).HasMaxLength(450);
        builder.Property(x => x.ProofHash).HasMaxLength(64).IsUnicode(false);
        builder.HasIndex(x => x.SendWindowUtc);
    }
}
