using System;
using System.Collections.Generic;
using System.Text;
<<<<<<< HEAD
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructureDI(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddDbContext<SynTraceDbContext>(options =>
            options.UseSqlServer(
                configuration.GetConnectionString("ConnectionDB")
                )
            );

            services.AddMemoryCache();

            return services;
        }
    }
}
