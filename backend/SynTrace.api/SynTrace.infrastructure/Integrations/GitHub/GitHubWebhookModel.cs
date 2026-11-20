using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities.GitHub;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public static class GitHubWebhookModel
{
    public static void ConfigureGitHubWebhookDelivery(this ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<GitHubWebhookDelivery>(entity =>
        {
            entity.ToTable("GitHubWebhookDeliveries");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).ValueGeneratedNever();
            entity.Property(x => x.CompanyId).HasMaxLength(450);
            entity.Property(x => x.BindingId).HasMaxLength(450);
            entity.Property(x => x.EventName).HasMaxLength(40);
            entity.Property(x => x.Action).HasMaxLength(40);
            entity.Property(x => x.LastFailureType).HasMaxLength(80);
            entity.HasIndex(x => new { x.NextDispatchAtUtc, x.CompletedAtUtc, x.DeadLetteredAtUtc });
            entity.HasIndex(x => x.ReceivedAtUtc);
        });
    }
}
