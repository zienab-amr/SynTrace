using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Contracts.Integrations.GitHub;

namespace SynTrace.Infrastructure.Integrations.GitHub;

public static class GitHubOAuthRegistration
{
    public static IServiceCollection AddGitHubOAuth(this IServiceCollection services, IConfiguration configuration, bool workerOnly = false)
    {
        services.Configure<GitHubOAuthOptions>(configuration.GetSection(GitHubOAuthOptions.SectionName));
        services.AddMemoryCache();
        services.AddHttpClient(GitHubApiClient.HttpClientName, client =>
        {
            client.DefaultRequestHeaders.UserAgent.ParseAdd("SynTrace-GitHub");
            client.Timeout = TimeSpan.FromSeconds(45);
        }).ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.AddScoped<GitHubApiClient>();
        if (!workerOnly)
            services.AddScoped<IGitHubOAuthService, GitHubOAuthService>();
        return services;
    }
}
