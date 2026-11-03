using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Integrations.Jira;
using SynTrace.Infrastructure.Options;
using SynTrace.Infrastructure.Persistence.Context;

namespace SynTrace.Infrastructure.Integrations.Jira;

public static class JiraIntegrationServiceCollectionExtensions
{
    /// <summary>API host: webhook endpoint, registration, API client, back-fill + maintenance jobs.</summary>
    public static IServiceCollection AddJiraIntegration(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<JiraWebhookOptions>(configuration.GetSection(JiraWebhookOptions.SectionName));

        services.AddScoped<JiraApiClient>();
        services.AddScoped<IJiraWebhookRegistrationService, JiraWebhookRegistrationService>();

        services.AddSingleton<JiraWebhookNormalizer>();
        services.AddScoped<IJiraWebhookIngestionService, JiraWebhookIngestionService>();

        services.AddScoped<IJiraBackfillService, JiraBackfillService>();
        services.AddSingleton<JiraBackfillQueue>();
        services.AddSingleton<IJiraBackfillQueue>(sp => sp.GetRequiredService<JiraBackfillQueue>());
        services.AddHostedService<JiraBackfillHostedService>();
        services.AddHostedService<JiraMaintenanceHostedService>();

        // The event processor is also registered here so integration tests / a single-process setup work.
        services.AddScoped<IJiraEventProcessor, JiraEventProcessor>();
        return services;
    }

    /// <summary>Worker host: only what is needed to consume events and write them to the database.</summary>
    public static IServiceCollection AddJiraEventProcessing(this IServiceCollection services, IConfiguration configuration)
    {
        // The Worker has no HTTP context / tenant: SynTraceDbContext has a constructor without ICurrentTenant for it.
        services.AddDbContext<SynTraceDbContext>(options =>
            options.UseSqlServer(configuration.GetConnectionString("ConnectionDB")));

        services.AddScoped<IJiraEventProcessor, JiraEventProcessor>();
        return services;
    }
}
