using System.Text.RegularExpressions;
using SynTrace.Contracts.IntegrationEvents.Jira;

namespace SynTrace.Infrastructure.Messaging.RabbitMQ.Publishing;

public sealed class JiraRoutingKeyResolver
{
    public string Resolve(JiraEventType eventType)
    {
        if (!Enum.IsDefined(eventType))
        {
            throw new ArgumentOutOfRangeException(
                nameof(eventType),
                eventType,
                "Unsupported Jira event type.");
        }

        var eventName = Regex.Replace(
            eventType.ToString(),
            @"([a-z0-9])([A-Z])",
            "$1.$2");

        return $"jira.{eventName.ToLowerInvariant()}";
    }
}
