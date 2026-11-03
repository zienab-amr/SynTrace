using System;
using System.Collections.Generic;
using System.Text;
using SynTrace.Contracts.IntegrationEvents.Jira;

namespace SynTrace.Application.Messaging
{
    public interface IJiraEventPublisher
    {
        public Task PublishAsync(
            CanonicalJiraEvent message,
            CancellationToken cancellationToken);
    }
}
