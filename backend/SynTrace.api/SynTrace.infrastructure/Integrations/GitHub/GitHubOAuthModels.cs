using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.GitHub;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public static class GitHubOAuthModels
{
    public static void ConfigureGitHubOAuthModels(this ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<GitHubInstallationOwnership>(entity =>
        {
            entity.ToTable("GitHubInstallationOwnerships");
            entity.HasKey(x => x.InstallationId);
            entity.Property(x => x.InstallationId).ValueGeneratedNever();
            entity.Property(x => x.CompanyId).HasMaxLength(450);
            entity.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<GitHubConnection>(entity =>
        {
            entity.ToTable("GitHubConnections");
            entity.HasKey(x => x.CompanyId);
            entity.Property(x => x.CompanyId).HasMaxLength(450);
            entity.Property(x => x.ConnectedByEmployeeId).HasMaxLength(450);
            entity.Property(x => x.GitHubAccountLogin).HasMaxLength(256);
            entity.HasIndex(x => x.InstallationId).IsUnique();
            entity.HasOne<GitHubInstallationOwnership>().WithMany().HasForeignKey(x => x.InstallationId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<Employee>().WithMany().HasForeignKey(x => x.ConnectedByEmployeeId).OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<GitHubEmployeeIdentity>(entity =>
        {
            entity.ToTable("GitHubEmployeeIdentities");
            entity.HasKey(x => new { x.CompanyId, x.EmployeeId });
            entity.Property(x => x.CompanyId).HasMaxLength(450);
            entity.Property(x => x.EmployeeId).HasMaxLength(450);
            entity.Property(x => x.GitHubLogin).HasMaxLength(256);
            entity.HasIndex(x => new { x.CompanyId, x.GitHubUserId }).IsUnique();
            entity.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<Employee>().WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<GitHubRepositoryBinding>(entity =>
        {
            entity.ToTable("GitHubRepositoryBindings");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasMaxLength(36);
            entity.Property(x => x.CompanyId).HasMaxLength(450);
            entity.Property(x => x.ProjectId).HasMaxLength(450);
            entity.Property(x => x.Owner).HasMaxLength(256);
            entity.Property(x => x.Name).HasMaxLength(256);
            entity.Property(x => x.FullName).HasMaxLength(513);
            entity.Property(x => x.DefaultBranch).HasMaxLength(1024);
            entity.HasIndex(x => x.ProjectId).IsUnique().HasFilter("[IsActive] = 1");
            entity.HasIndex(x => new { x.CompanyId, x.RepositoryId }).IsUnique().HasFilter("[IsActive] = 1");
            entity.HasIndex(x => new { x.InstallationId, x.RepositoryId, x.IsActive });
            entity.HasOne<Project>().WithMany().HasForeignKey(x => x.ProjectId).OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<GitHubOAuthCompletion>(entity =>
        {
            entity.ToTable("GitHubOAuthCompletions");
            entity.HasKey(x => x.ProofHash);
            entity.Property(x => x.ProofHash).HasMaxLength(64).IsUnicode(false).IsFixedLength();
            entity.Property(x => x.CompanyId).HasMaxLength(450);
            entity.Property(x => x.EmployeeId).HasMaxLength(450);
            entity.Property(x => x.GitHubLogin).HasMaxLength(256);
            entity.HasIndex(x => x.ExpiresAt);
        });
    }
}
