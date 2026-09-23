using System;
using System.Collections.Generic;
using System.Text;
<<<<<<< HEAD
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SynTrace.Domain.Entities;

namespace SynTrace.Infrastructure.Persistence.Context
{
    public class SynTraceDbContext :IdentityDbContext
    {
        public SynTraceDbContext(DbContextOptions<SynTraceDbContext> options): base(options) {}
        public DbSet<Company> Companies { get; set; }
        public DbSet<Employee> Employees { get; set; }

=======

namespace SynTrace.Infrastructure.Persistence.Context
{
    internal class SynTraceDbContext
    {
>>>>>>> b223cd8d0e2508b9ae3eec5f0b7dc6378c833a26
    }
}
