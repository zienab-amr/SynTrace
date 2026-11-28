// API requests target the domain root (/api), independently of the React mount path (/web).
// VITE_API_URL is an origin only. A mistakenly pasted Scalar URL (/scalar/v1#...) or /api suffix
// is normalized back to the origin so endpoint paths remain /api/... exactly once.
function normalizeApiOrigin(value) {
  const configured = String(value ?? '').trim(); // trims regular and non-breaking trailing spaces
  if (!configured) return '';

  let url;
  try {
    url = new URL(configured);
  } catch {
    throw new Error('VITE_API_URL must be an absolute backend origin, for example https://api.example.com.');
  }

  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
    throw new Error('VITE_API_URL must use HTTP(S) and must not contain credentials.');
  }

  if (url.pathname !== '/' || url.search || url.hash) {
    console.warn('VITE_API_URL should contain only the backend origin. The URL path, query and fragment were ignored.');
  }

  return url.origin;
}

export const API_BASE_URL = normalizeApiOrigin(import.meta.env.VITE_API_URL);

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
