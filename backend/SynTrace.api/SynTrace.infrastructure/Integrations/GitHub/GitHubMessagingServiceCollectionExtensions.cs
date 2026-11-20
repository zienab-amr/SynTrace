using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Integrations.GitHub;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public static class GitHubMessagingServiceCollectionExtensions
{
    public static IServiceCollection AddGitHubMessaging(this IServiceCollection services, IConfiguration configuration,
        bool runBackgroundJobs)
    {
        services.AddOptions<GitHubMessagingOptions>()
            .Bind(configuration.GetSection(GitHubMessagingOptions.SectionName))
            .Validate(x => x.MaxAttempts is >= 1 and <= 30 && x.RetryDelaySeconds is >= 1 and <= 600 &&
                x.DeliveryRecoveryMinutes is >= 5 and <= 1440 && x.RetentionDays >= 7 && x.Prefetch > 0,
                "Invalid GitHub RabbitMQ retry, recovery, retention or prefetch configuration.")
            .ValidateOnStart();
        services.AddSingleton<GitHubRabbitMq>();
        services.AddSingleton<IGitHubAiPublisher>(p => p.GetRequiredService<GitHubRabbitMq>());
        services.AddScoped<IGitHubWebhookIngress, GitHubWebhookIngress>();

        if (runBackgroundJobs)
        {
            services.AddScoped<GitHubWebhookQueue>();
            services.AddHostedService<GitHubWebhookDispatcher>();
            services.AddHostedService<GitHubWebhookConsumer>();
        }
        return services;
    }
}
