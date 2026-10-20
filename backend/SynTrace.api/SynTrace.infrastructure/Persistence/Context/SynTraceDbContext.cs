using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SynTrace.Application.Contracts;
using SynTrace.Domain.Entities;

namespace SynTrace.Infrastructure.Persistence.Context
{
    public class SynTraceDbContext : IdentityDbContext
    {
        private readonly ICurrentTenant _currentTenant;
        public SynTraceDbContext(DbContextOptions<SynTraceDbContext> options, ICurrentTenant currentTenant) : base(options) 
        {
            _currentTenant = currentTenant;
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.ApplyConfigurationsFromAssembly(
                typeof(SynTraceDbContext).Assembly);

            modelBuilder.Entity<JiraConnection>()
                .HasOne(x => x.Company)
                .WithMany()
                .HasForeignKey(x => x.CompanyId)
                .OnDelete(DeleteBehavior.NoAction);

            modelBuilder.Entity<JiraConnection>()
                .HasOne(x => x.ConnectedByEmployee)
                .WithMany()
                .HasForeignKey(x => x.ConnectedByEmployeeId)
                .OnDelete(DeleteBehavior.NoAction);

            modelBuilder.Entity<JiraOAuthState>()
                .HasOne(x => x.Company)
                .WithMany()
                .HasForeignKey(x => x.CompanyId)
                .OnDelete(DeleteBehavior.NoAction);

            modelBuilder.Entity<JiraOAuthState>()
                .HasOne(x => x.Employee)
                .WithMany()
                .HasForeignKey(x => x.EmployeeId)
                .OnDelete(DeleteBehavior.NoAction);
        }

        public DbSet<Company> Companies { get; set; }
        public DbSet<Employee> Employees { get; set; }

        public DbSet<RefreshToken> RefreshTokens { get; set; }
        public DbSet<JiraOAuthState> JiraOAuthStates { get; set; }
        public DbSet<JiraConnection> JiraConnections { get; set; }

    }
}
