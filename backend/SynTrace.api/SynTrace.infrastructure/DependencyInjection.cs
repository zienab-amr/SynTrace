using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Contracts;
using SynTrace.Application.Contracts.Auth;
using SynTrace.Application.Contracts.Integrations.Jira;
using SynTrace.Domain.Entities;
using SynTrace.Domain.Interfaces;
using SynTrace.Infrastructure.ExternalServices;
using SynTrace.Infrastructure.Identity;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;
using SynTrace.Infrastructure.Repositories;
using SynTrace.Infrastructure.Services.Integrations.Jira;

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

            // JWT Bearer Authentication
            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme =
                    JwtBearerDefaults.AuthenticationScheme;

                options.DefaultChallengeScheme =
                    JwtBearerDefaults.AuthenticationScheme;
            })
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateIssuerSigningKey = true,
                    ValidateLifetime = true,

                    ValidIssuer = configuration["jwt:issuer"],
                    ValidAudience = configuration["jwt:audience"],

                    IssuerSigningKey = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(
                            configuration["jwt:key"]!)),

                    ClockSkew = TimeSpan.Zero
                };
            });

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
            services.AddScoped<IRoleService, RoleService>();
            services.AddScoped<IJiraOAuthService, JiraOAuthService>();

            //JWT Token Service
            services.AddScoped<ICurrentTenant, CurrentTenant>();
            services.AddScoped<ICurrentEmployee, CurrentEmployee>();
            services.AddScoped<ICurrentRole, CurrentRole>();

            //Repositories
            services.AddScoped<IEmployeeRepository, EmployeeRepository>();
            services.AddScoped<IJiraOAuthConnectionRepository, JiraOAuthConnectionRepository>();

            //Http Client
            services.AddHttpClient();

            //binding configuration
            services.Configure<JiraOAuthOptions>(configuration.GetSection("JiraOAuth"));

            return services;
        }
    }
}
