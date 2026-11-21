using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Entities.Jira;
using SynTrace.Domain.Entities.Integrations;
using SynTrace.Infrastructure.Integrations.GitHub;

namespace SynTrace.Infrastructure.Persistence.Context
{
    public class SynTraceDbContext : IdentityDbContext<Employee, Role, string>
    {
        private readonly ICurrentTenant? _currentTenant;
        public bool BypassTenantFilter { get; set; } = false;

        public SynTraceDbContext(
            DbContextOptions<SynTraceDbContext> options,
            ICurrentTenant currentTenant) : base(options)
        {
            _currentTenant = currentTenant;
        }

        // Used for design-time operations
        public SynTraceDbContext(DbContextOptions<SynTraceDbContext> options)
            : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.ApplyConfigurationsFromAssembly(
                typeof(SynTraceDbContext).Assembly);

            ConfigureRole(modelBuilder);
            ConfigureClient(modelBuilder);
            ConfigureProject(modelBuilder);
            ConfigureEmployeeProject(modelBuilder);

            ConfigureTenantEntities(modelBuilder);

            ConfigureJiraConnections(modelBuilder);
            ConfigureOAuthState(modelBuilder);
            modelBuilder.ConfigureGitHubOAuthModels();
            modelBuilder.ConfigureGitHubWebhookDelivery();

            ConfigureJiraEntities(modelBuilder);

            ConfigureMeetingNote(modelBuilder);

        }

        #region Tenant Configuration

        private void ConfigureTenantEntities(ModelBuilder modelBuilder)
        {
            ConfigureTenantOwned<Client>(modelBuilder);
            ConfigureTenantOwned<Project>(modelBuilder);
            ConfigureTenantOwned<MeetingNote>(modelBuilder);
            ConfigureTenantOwned<EmployeeProject>(modelBuilder);

            ConfigureTenantOwned<JiraProject>(modelBuilder);
            ConfigureTenantOwned<JiraIssue>(modelBuilder);
            ConfigureTenantOwned<JiraComment>(modelBuilder);
            ConfigureTenantOwned<JiraSprint>(modelBuilder);
            ConfigureTenantOwned<JiraUser>(modelBuilder);
            ConfigureTenantOwned<ProcessedJiraEvent>(modelBuilder);
        }

        private void ConfigureTenantOwned<T>(ModelBuilder modelBuilder)
    where T : class, ITenantOwned
        {
            var entity = modelBuilder.Entity<T>();

            entity.HasQueryFilter(x =>
                BypassTenantFilter ||
                (
                    _currentTenant != null &&
                    x.CompanyId == _currentTenant.CompanyId
                ));

            entity.Property(x => x.CompanyId)
                .HasMaxLength(450);
        }

        #endregion

        #region Identity Configuration

        private static void ConfigureRole(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Role>(entity =>
            {
                entity.HasOne(x => x.Company)
                    .WithMany()
                    .HasForeignKey(x => x.CompanyId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasIndex(x => x.NormalizedName)
                    .HasDatabaseName("RoleNameIndex")
                    .IsUnique(false);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.NormalizedName
                })
                .IsUnique()
                .HasDatabaseName("Role_Company_NormalizedName");
            });
        }

        #endregion

        #region Project Configuration

        private static void ConfigureClient(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Client>(entity =>
            {
                entity.HasOne(x => x.Company)
                    .WithMany()
                    .HasForeignKey(x => x.CompanyId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }

        private static void ConfigureProject(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Project>(entity =>
            {
                entity.HasOne(x => x.Company)
                    .WithMany()
                    .HasForeignKey(x => x.CompanyId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Client)
                    .WithMany(x => x.Projects)
                    .HasForeignKey(x => x.ClientId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.ClientId
                });
            });
        }

        private static void ConfigureEmployeeProject(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<EmployeeProject>(entity =>
            {
                entity.HasOne(x => x.Company)
                    .WithMany()
                    .HasForeignKey(x => x.CompanyId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.EmployeeId,
                    x.ProjectId
                })
                .IsUnique();

                entity.HasOne(x => x.Employee)
                    .WithMany(x => x.EmployeeProjects)
                    .HasForeignKey(x => x.EmployeeId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Project)
                    .WithMany(x => x.EmployeeProjects)
                    .HasForeignKey(x => x.ProjectId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }

        #endregion

        #region Jira Configuration

        private static void ConfigureJiraConnections(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<JiraConnection>(entity =>
            {
                entity.HasOne(x => x.Company)
                    .WithMany()
                    .HasForeignKey(x => x.CompanyId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.ConnectedByEmployee)
                    .WithMany()
                    .HasForeignKey(x => x.ConnectedByEmployeeId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasIndex(x => x.CompanyId)
                    .IsUnique()
                    .HasFilter("[JiraConnectionType] = 0 AND [status] = 1");

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.ConnectedByEmployeeId
                })
                .IsUnique()
                .HasDatabaseName("UX_JiraConnections_ActiveEmployee")
                .HasFilter("[JiraConnectionType] = 1 AND [status] = 1");

                entity.Property(x => x.WebhookSecretHash)
                    .HasMaxLength(128);

                entity.Property(x => x.LastSyncError)
                    .HasMaxLength(1000);
            });
        }

        private static void ConfigureOAuthState(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<OAuthState>(entity =>
            {
                entity.Property(x => x.StateHash).HasMaxLength(64).IsUnicode(false);
                entity.HasIndex(x => x.StateHash).IsUnique();
                entity.HasIndex(x => x.ExpiresAt);

                entity.HasOne(x => x.Company)
                    .WithMany()
                    .HasForeignKey(x => x.CompanyId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Employee)
                    .WithMany()
                    .HasForeignKey(x => x.EmployeeId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }

        private static void ConfigureJiraEntities(ModelBuilder modelBuilder)
        {
            ConfigureJiraProject(modelBuilder);
            ConfigureJiraIssue(modelBuilder);
            ConfigureJiraComment(modelBuilder);
            ConfigureJiraSprint(modelBuilder);
            ConfigureJiraUser(modelBuilder);
            ConfigureProcessedJiraEvent(modelBuilder);
        }

        private static void ConfigureJiraProject(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<JiraProject>(entity =>
            {
                entity.Property(x => x.ExternalId).HasMaxLength(64);
                entity.Property(x => x.Key).HasMaxLength(64);
                entity.Property(x => x.Name).HasMaxLength(512);
                entity.Property(x => x.ProjectTypeKey).HasMaxLength(64);
                entity.Property(x => x.LeadAccountId).HasMaxLength(128);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.ExternalId
                }).IsUnique();

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.Key
                });
            });
        }

        private static void ConfigureJiraIssue(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<JiraIssue>(entity =>
            {
                entity.Property(x => x.ExternalId).HasMaxLength(64);
                entity.Property(x => x.Key).HasMaxLength(64);
                entity.Property(x => x.ProjectExternalId).HasMaxLength(64);
                entity.Property(x => x.ProjectKey).HasMaxLength(64);
                entity.Property(x => x.Summary).HasMaxLength(1024);
                entity.Property(x => x.Status).HasMaxLength(128);
                entity.Property(x => x.AssigneeAccountId).HasMaxLength(128);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.ExternalId
                }).IsUnique();

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.Key
                });

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.ProjectExternalId
                });
            });
        }

        private static void ConfigureJiraComment(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<JiraComment>(entity =>
            {
                entity.Property(x => x.ExternalId).HasMaxLength(64);
                entity.Property(x => x.IssueExternalId).HasMaxLength(64);
                entity.Property(x => x.IssueKey).HasMaxLength(64);
                entity.Property(x => x.AuthorAccountId).HasMaxLength(128);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.ExternalId
                }).IsUnique();

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.IssueExternalId
                });
            });
        }

        private static void ConfigureJiraSprint(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<JiraSprint>(entity =>
            {
                entity.Property(x => x.ExternalId).HasMaxLength(64);
                entity.Property(x => x.Name).HasMaxLength(512);
                entity.Property(x => x.State).HasMaxLength(32);
                entity.Property(x => x.BoardExternalId).HasMaxLength(64);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.ExternalId
                }).IsUnique();
            });
        }

        private static void ConfigureJiraUser(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<JiraUser>(entity =>
            {
                entity.Property(x => x.AccountId).HasMaxLength(128);
                entity.Property(x => x.DisplayName).HasMaxLength(512);

                entity.HasIndex(x => new
                {
                    x.CompanyId,
                    x.AccountId
                }).IsUnique();
            });
        }

        private static void ConfigureProcessedJiraEvent(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ProcessedJiraEvent>(entity =>
            {
                entity.Property(x => x.JiraConnectionId).HasMaxLength(450);
                entity.Property(x => x.EventId).HasMaxLength(64);
                entity.Property(x => x.EventType).HasMaxLength(64);

                entity.HasOne<JiraConnection>()
                    .WithMany()
                    .HasForeignKey(x => x.JiraConnectionId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasIndex(x => new
                {
                    x.JiraConnectionId,
                    x.EventId
                })
                .IsUnique()
                .HasDatabaseName("UX_ProcessedJiraEvents_Connection_Event");

                entity.HasIndex(x => x.ProcessedAt);
            });
        }

        #endregion

        private static void ConfigureMeetingNote(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<MeetingNote>(entity =>
            {
                entity.HasOne(x => x.Company)
                    .WithMany()
                    .HasForeignKey(x => x.CompanyId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Client)
                    .WithMany()
                    .HasForeignKey(x => x.ClientId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(x => x.Project)
                    .WithMany(x => x.MeetingNotes)
                    .HasForeignKey(x => x.ProjectId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }

        #region DbSets

        public DbSet<Company> Companies { get; set; }
        public DbSet<Employee> Employees { get; set; }
        public DbSet<EmployeeProject> EmployeeProjects { get; set; }
        public DbSet<Project> Projects { get; set; }
        public DbSet<Client> Clients { get; set; }
        public DbSet<MeetingNote> MeetingNotes { get; set; }
        public DbSet<Role> Roles { get; set; }
        public DbSet<RefreshToken> RefreshTokens { get; set; }

        // Jira
        public DbSet<OAuthState> OAuthStates { get; set; }
        public DbSet<JiraConnection> JiraConnections { get; set; }
        public DbSet<JiraProject> JiraProjects { get; set; }
        public DbSet<JiraIssue> JiraIssues { get; set; }
        public DbSet<JiraComment> JiraComments { get; set; }
        public DbSet<JiraSprint> JiraSprints { get; set; }
        public DbSet<JiraUser> JiraUsers { get; set; }
        public DbSet<ProcessedJiraEvent> ProcessedJiraEvents { get; set; }

        #endregion
    }
}