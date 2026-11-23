await OAuthStateChecks.RunAsync();
Console.WriteLine("OAuth state integration checks passed.");
await GitHubWebhookChecks.RunAsync();
Console.WriteLine("GitHub webhook integration checks passed.");
await GitHubOAuthChecks.RunAsync();
Console.WriteLine("GitHub OAuth integration checks passed.");
await GitHubSyncChecks.RunAsync();
Console.WriteLine("GitHub sync integration checks passed.");
await AssistantScopeChecks.RunAsync();
Console.WriteLine("Assistant project scope checks passed.");
await IdentityChecks.RunAsync();
Console.WriteLine("Identity and employee role checks passed.");
await JiraProjectionChecks.RunAsync();
Console.WriteLine("Jira projection checks passed.");
await KnowledgeSourceChecks.RunAsync();
Console.WriteLine("Knowledge source checks passed.");

await PendingAssistantTurnChecks.RunAsync();
Console.WriteLine("Pending AI turn registry checks passed.");

await InternalEmployeeIdentityChecks.RunAsync();
Console.WriteLine("Internal employee identity mapping checks passed.");
