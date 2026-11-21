using SynTrace.Infrastructure.Integrations.Jira;
using SynTrace.Infrastructure.Integrations.GitHub;
using SynTrace.Infrastructure.Messaging.RabbitMQ;
using SynTrace.Infrastructure.Messaging.RabbitMQ.Configuration;
using SynTrace.Worker;

var builder = Host.CreateApplicationBuilder(args);

// RabbitMQ connection settings
builder.Services.AddRabbitMqInfrastructure(options =>
{
    builder.Configuration
        .GetSection(RabbitMqOptions.SectionName)
        .Bind(options);
});

// RabbitMQ topology settings
builder.Services.Configure<RabbitMqTopologyOptions>(
    builder.Configuration.GetSection(RabbitMqTopologyOptions.SectionName));

// NEW: DbContext + IJiraEventProcessor (needs ConnectionStrings:ConnectionDB in the Worker's config)
builder.Services.AddJiraEventProcessing(builder.Configuration);
builder.Services.AddGitHubOAuth(builder.Configuration, workerOnly: true);

// Register background worker
builder.Services.AddHostedService<Worker>();

var host = builder.Build();

host.Run();
