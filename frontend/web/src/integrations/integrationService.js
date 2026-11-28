// Feature-level integration API. Implementations remain centralized in workspaceService
// so the existing API client, authentication and error handling are reused.
export {
  connectGitHub,
  getGitHubPending,
  completeGitHubConnection,
  getGitHubRepositories,
  getGitHubProjectStatus,
  mapGitHubRepository,
  unmapGitHubRepository,
  syncGitHubProject,
  connectJira,
  getPendingJiraSites,
  completeJiraConnection,
  startJiraSync,
} from '../services/workspaceService.js';

/** Slack is intentionally not wired to a fake client-side endpoint. */
export const slackIntegrationAvailability = Object.freeze({
  available: false,
  reason: 'The backend does not currently expose Slack OAuth, callback, token storage or event/webhook endpoints.',
});
