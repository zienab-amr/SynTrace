
using Microsoft.Extensions.DependencyInjection;
using SynTrace.Application.Messaging;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Connections;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Consumers;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Publishing;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Topology;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ;

public static class RabbitMqServiceCollectionExtensions
{
    public static IServiceCollection AddRabbitMqInfrastructure(
        this IServiceCollection services,
        Action<RabbitMqOptions> configureOptions)
    {
        // Bind RabbitMQ connection settings
        services.Configure(configureOptions);

        // Connection and topology
        services.AddSingleton<RabbitMqConnectionProvider>();
        services.AddSingleton<RabbitMqTopologyInitializer>();

        // Routing key resolver
        services.AddSingleton<JiraRoutingKeyResolver>();

        // Publisher
        services.AddScoped<IJiraEventPublisher, RabbitMqJiraEventPublisher>();

        // Consumer
        services.AddSingleton<JiraEventConsumerService>();

        // Initialize RabbitMQ topology
        services.AddHostedService<RabbitMqTopologyHostedService>();

        return services;
    }
}
