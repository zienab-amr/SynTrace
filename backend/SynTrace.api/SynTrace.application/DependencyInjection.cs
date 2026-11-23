using SynTrace.Application.Behaviors;
using SynTrace.Application.Contracts;
using SynTrace.Application.Services;
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
            services.AddScoped<IConversationService, ConversationService>();
            services.AddSingleton<PendingAssistantTurnStore>();
            services.AddScoped<SynTrace.Application.Contracts.Assistant.IAssistantConversationService,
                AssistantConversationService>();
            services.AddMediatR(cfg =>
            {
                cfg.RegisterServicesFromAssembly(typeof(DependencyInjection).Assembly);
                cfg.AddOpenBehavior(typeof(ValidationBehavior<,>));
            });

            return services;
        }
    }
}
