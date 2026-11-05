using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Enums;

namespace SynTrace.Infrastructure.Persistence.Context
{
    public class SynTraceDbContext : IdentityDbContext<Employee, Role, string>
    {
        private readonly ICurrentTenant? _currentTenant;

        public SynTraceDbContext(DbContextOptions<SynTraceDbContext> options, ICurrentTenant currentTenant) : base(options)
        {
            _currentTenant = currentTenant;
        }

        public SynTraceDbContext(DbContextOptions<SynTraceDbContext> options) : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Role>(entity =>
            {
                entity.HasOne(x => x.Company).WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);

                entity.HasIndex(x => x.NormalizedName)
                    .HasDatabaseName("RoleNameIndex")
                    .IsUnique(false);

                entity.HasIndex(x => new { x.CompanyId, x.NormalizedName })
                    .IsUnique()
                    .HasDatabaseName("Role_Company_NormalizedName");
            });
                
            modelBuilder.ApplyConfigurationsFromAssembly(typeof(SynTraceDbContext).Assembly);

            modelBuilder.Entity<JiraConnection>()
                .HasOne(x => x.Company).WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);

            modelBuilder.Entity<JiraConnection>()
                .HasOne(x => x.ConnectedByEmployee).WithMany().HasForeignKey(x => x.ConnectedByEmployeeId).OnDelete(DeleteBehavior.NoAction);

            modelBuilder.Entity<JiraConnection>()
                .HasIndex(c => c.CompanyId).IsUnique()
                .HasFilter("[JiraConnectionType] = 0 AND [status] = 1");

            modelBuilder.Entity<JiraConnection>()
                .HasIndex(c => new { c.CompanyId, c.ConnectedByEmployeeId })
                .IsUnique()
                .HasDatabaseName("UX_JiraConnections_ActiveEmployee")
                .HasFilter("[JiraConnectionType] = 1 AND [status] = 1");

            modelBuilder.Entity<JiraOAuthState>()
                .HasOne(x => x.Company).WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.NoAction);

            modelBuilder.Entity<JiraOAuthState>()
                .HasOne(x => x.Employee).WithMany().HasForeignKey(x => x.EmployeeId).OnDelete(DeleteBehavior.NoAction);

            ConfigureTenantOwned<JiraProject>(modelBuilder);
            ConfigureTenantOwned<JiraIssue>(modelBuilder);
            ConfigureTenantOwned<JiraComment>(modelBuilder);
            ConfigureTenantOwned<JiraSprint>(modelBuilder);
            ConfigureTenantOwned<JiraUser>(modelBuilder);
            ConfigureTenantOwned<ProcessedJiraEvent>(modelBuilder);


            modelBuilder.Entity<JiraProject>(b =>
            {
                b.Property(x => x.ExternalId).HasMaxLength(64);
                b.Property(x => x.Key).HasMaxLength(64);
                b.Property(x => x.Name).HasMaxLength(512);
                b.Property(x => x.ProjectTypeKey).HasMaxLength(64);
                b.Property(x => x.LeadAccountId).HasMaxLength(128);
                b.HasIndex(x => new { x.CompanyId, x.ExternalId }).IsUnique();
                b.HasIndex(x => new { x.CompanyId, x.Key });
            });

            modelBuilder.Entity<JiraIssue>(b =>
            {
                b.Property(x => x.ExternalId).HasMaxLength(64);
                b.Property(x => x.Key).HasMaxLength(64);
                b.Property(x => x.ProjectExternalId).HasMaxLength(64);
                b.Property(x => x.ProjectKey).HasMaxLength(64);
                b.Property(x => x.Summary).HasMaxLength(1024);
                b.Property(x => x.Status).HasMaxLength(128);
                b.Property(x => x.AssigneeAccountId).HasMaxLength(128);
                b.HasIndex(x => new { x.CompanyId, x.ExternalId }).IsUnique();
                b.HasIndex(x => new { x.CompanyId, x.Key });
                b.HasIndex(x => new { x.CompanyId, x.ProjectExternalId });
            });

            modelBuilder.Entity<JiraComment>(b =>
            {
                b.Property(x => x.ExternalId).HasMaxLength(64);
                b.Property(x => x.IssueExternalId).HasMaxLength(64);
                b.Property(x => x.IssueKey).HasMaxLength(64);
                b.Property(x => x.AuthorAccountId).HasMaxLength(128);
                b.HasIndex(x => new { x.CompanyId, x.ExternalId }).IsUnique();
                b.HasIndex(x => new { x.CompanyId, x.IssueExternalId });
            });

            modelBuilder.Entity<JiraSprint>(b =>
            {
                b.Property(x => x.ExternalId).HasMaxLength(64);
                b.Property(x => x.Name).HasMaxLength(512);
                b.Property(x => x.State).HasMaxLength(32);
                b.Property(x => x.BoardExternalId).HasMaxLength(64);
                b.HasIndex(x => new { x.CompanyId, x.ExternalId }).IsUnique();
            });

            modelBuilder.Entity<JiraUser>(b =>
            {
                b.Property(x => x.AccountId).HasMaxLength(128);
                b.Property(x => x.DisplayName).HasMaxLength(512);
                b.HasIndex(x => new { x.CompanyId, x.AccountId }).IsUnique();
            });

            modelBuilder.Entity<ProcessedJiraEvent>(b =>
            {
                b.Property(x => x.JiraConnectionId).HasMaxLength(450);
                b.Property(x => x.EventId).HasMaxLength(64);
                b.Property(x => x.EventType).HasMaxLength(64);
                b.HasOne<JiraConnection>().WithMany().HasForeignKey(x => x.JiraConnectionId).OnDelete(DeleteBehavior.NoAction);
                b.HasIndex(x => new { x.JiraConnectionId, x.EventId }).IsUnique().HasDatabaseName("UX_ProcessedJiraEvents_Connection_Event");
                b.HasIndex(x => x.ProcessedAt);   // for a future retention/cleanup job
            });

            modelBuilder.Entity<JiraConnection>(b =>
            {
                b.Property(x => x.WebhookSecretHash).HasMaxLength(128);
                b.Property(x => x.LastSyncError).HasMaxLength(1000);
            });
        }

        private static void ConfigureTenantOwned<T>(ModelBuilder modelBuilder) where T : class, ITenantOwned
        {
            modelBuilder.Entity<T>().Property(nameof(ITenantOwned.CompanyId)).HasMaxLength(450);
            modelBuilder.Entity<T>()
                .HasOne<Company>().WithMany()
                .HasForeignKey(nameof(ITenantOwned.CompanyId))
                .OnDelete(DeleteBehavior.NoAction);
        }

        public DbSet<Company> Companies { get; set; }
        public DbSet<Employee> Employees { get; set; }
        public DbSet<Role> Roles { get; set; }

        public DbSet<RefreshToken> RefreshTokens { get; set; }
        public DbSet<JiraOAuthState> JiraOAuthStates { get; set; }
        public DbSet<JiraConnection> JiraConnections { get; set; }
        public DbSet<JiraProject> JiraProjects { get; set; }
        public DbSet<JiraIssue> JiraIssues { get; set; }
        public DbSet<JiraComment> JiraComments { get; set; }
        public DbSet<JiraSprint> JiraSprints { get; set; }
        public DbSet<JiraUser> JiraUsers { get; set; }
        public DbSet<ProcessedJiraEvent> ProcessedJiraEvents { get; set; }
    }
}
