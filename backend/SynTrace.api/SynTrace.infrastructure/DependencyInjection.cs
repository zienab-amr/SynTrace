using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.ExternalServices;
using SynTrace.Infrastructure.Identity;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Repositories;

namespace SynTrace.Infrastructure
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddInfrastructureDI(this IServiceCollection services, IConfiguration configuration)
        {
            // Connection DataBase
            services.AddDbContext<SynTraceDbContext>(options =>
            options.UseSqlServer(
                configuration.GetConnectionString("ConnectionDB")
                )
            );

            // Identity
            services.AddIdentity<Employee, IdentityRole>()
                .AddEntityFrameworkStores<SynTraceDbContext>()
                .AddDefaultTokenProviders();

            // Cache
            services.AddMemoryCache();

            //Services
            services.AddHttpContextAccessor();

            // Identity Services
            services.AddScoped<IRegisterService, RegisterService>();
            services.AddScoped<ILoginService, LoginService>();
            services.AddScoped<IOTPService, OTPService>();
            services.AddScoped<IEmailService, EmailService>();
            services.AddScoped<ITokenService, TokenService>();
            services.AddScoped<IForgotPasswordService, ForgotPasswordService>();
            services.AddScoped<ICurrentTenant, CurrentTenant>();
            services.AddScoped<IRoleService, RoleService>();
            services.AddScoped<IEmployeeRepository, EmployeeRepository>();


            return services;
        }
    }
}
