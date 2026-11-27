// API requests intentionally target the domain root (/api), not the React base path (/web).
// In production, an empty VITE_API_URL uses same-origin absolute API paths. Locally, keep the
// Docker-exposed backend default unless VITE_API_URL explicitly overrides it.
const configuredApiUrl = (import.meta.env.VITE_API_URL || '').trim();
export const API_BASE_URL = configuredApiUrl
  ? configuredApiUrl.replace(/\/+$/, '')
  : (import.meta.env.PROD ? '' : 'http://localhost:8081');

// Mocks are opt-in for isolated UI work only. Real backend is the default.
export const USE_MOCK_AUTH = !import.meta.env.PROD && import.meta.env.VITE_USE_MOCK_AUTH === 'true';

export const ENDPOINTS = {
  login: '/api/Auth/login',
  refresh: '/api/Auth/refresh-token',
  logout: '/api/Auth/logout',
  sendOtp: '/api/Auth/send-otp',
  verifyOtp: '/api/Auth/verify-otp',
  register: '/api/Auth/register',
  resetPassword: '/api/Auth/reset-password',
  me: '/api/Employee/me',
  employees: '/api/Employee/all-employee',
  clients: '/api/Client',
  projects: '/api/projects',
  knowledgeSources: '/api/knowledge/sources',
  jiraConnect: '/api/integrations/Jira/connect-jira',
  jiraPendingSites: '/api/integrations/Jira/pending-company-sites',
  jiraComplete: '/api/integrations/Jira/complete-company-connection',
  jiraSyncStatus: '/api/integrations/jira/sync/status',
  jiraSync: '/api/integrations/jira/sync?reregisterWebhook=false',
  githubConnect: '/api/integrations/github/connect',
  githubCompany: '/api/integrations/github/company',
  githubPending: (completionId) => `/api/integrations/github/pending?completionId=${encodeURIComponent(completionId)}`,
  githubComplete: '/api/integrations/github/complete',
  githubRepositories: '/api/integrations/github/repositories',
  githubProject: (projectId) => `/api/integrations/github/projects/${encodeURIComponent(projectId)}`,
  githubProjectRepository: (projectId) => `/api/integrations/github/projects/${encodeURIComponent(projectId)}/repository`,
  githubProjectSync: (projectId) => `/api/integrations/github/projects/${encodeURIComponent(projectId)}/sync`,
  assistantConversations: '/api/assistant/conversations',
  assistantAsk: '/api/assistant/ask',
  assistantMessages: (conversationId) => `/api/assistant/conversations/${encodeURIComponent(conversationId)}/messages`,
  assistantConversation: (conversationId) => `/api/assistant/conversations/${encodeURIComponent(conversationId)}`,
  knowledgeSource: (sourceId) => `/api/knowledge/sources/${encodeURIComponent(sourceId)}`,
  project: (projectId) => `/api/projects/${encodeURIComponent(projectId)}`,
  projectJira: (projectId) => `/api/projects/${encodeURIComponent(projectId)}/jira`,
};
