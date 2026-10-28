using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Extensions.DependencyInjection;

namespace SynTrace.Application
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddApplicationDI(
            this IServiceCollection services)
        {
            services.AddMediatR(cfg =>
                cfg.RegisterServicesFromAssembly(
                    typeof(DependencyInjection).Assembly));

            return services;
        }
    }
}
