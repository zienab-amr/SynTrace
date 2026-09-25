using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;

namespace SynTrace.Infrastructure.Persistence.Context
{
    public class SynTraceDbContext : IdentityDbContext
    {
        public SynTraceDbContext(DbContextOptions<SynTraceDbContext> options) : base(options) { }
        public DbSet<Company> Companies { get; set; }
        public DbSet<Employee> Employees { get; set; }

        public DbSet<RefreshToken> RefreshTokens { get; set; }

    }
}
