import { ENDPOINTS } from '../config/api.js';
import { request } from './apiClient.js';

function unwrapPayload(value) {
  let current = value;
  for (let depth = 0; depth < 3; depth += 1) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) break;
    const nested = current.data ?? current.result ?? current.payload;
    if (!nested || nested === current) break;
    current = nested;
  }
  return current;
}

function unwrapArray(value) {
  const current = unwrapPayload(value);
  if (Array.isArray(current)) return current;
  for (const key of ['items', 'results', 'projects', 'clients', 'employees', 'knowledgeSources', 'sources', 'sites']) {
    if (Array.isArray(current?.[key])) return current[key];
  }
  return [];
}

function statusOf(result) {
  return result.status === 'fulfilled' ? 'Available' : 'Unavailable';
}

function errorOf(result) {
  return result.status === 'rejected'
    ? (result.reason?.data?.detail || result.reason?.data?.message || result.reason?.message || 'Request failed')
    : '';
}

export async function getWorkspaceSnapshot() {
  const results = await Promise.allSettled([
    request(`${ENDPOINTS.projects}?offset=0`),
    request(ENDPOINTS.clients),
    request(ENDPOINTS.employees),
    request(`${ENDPOINTS.knowledgeSources}?skip=0&take=100`),
    request(ENDPOINTS.jiraSyncStatus),
    request(ENDPOINTS.githubCompany),
  ]);

  const [projectsResult, clientsResult, employeesResult, sourcesResult, jiraResult, githubResult] = results;
  const projects = projectsResult.status === 'fulfilled' ? unwrapArray(projectsResult.value) : [];
  const clients = clientsResult.status === 'fulfilled' ? unwrapArray(clientsResult.value) : [];
  const employees = employeesResult.status === 'fulfilled' ? unwrapArray(employeesResult.value) : [];
  const knowledgeSources = sourcesResult.status === 'fulfilled' ? unwrapArray(sourcesResult.value) : [];

  let jiraStatus;
  let jiraState;
  if (jiraResult.status === 'fulfilled') {
    const status = unwrapPayload(jiraResult.value) || {};
    jiraStatus = { ...status, connected: typeof status.connected === 'boolean' ? status.connected : true };
    jiraState = jiraStatus.connected ? 'Connected' : 'Not connected';
  } else if (jiraResult.reason?.status === 404) {
    jiraStatus = { connected: false, syncStatus: 'NotConnected' };
    jiraState = 'Not connected';
  } else if (jiraResult.reason?.status === 403) {
    jiraStatus = { connected: null, error: 'Jira connection status is restricted to company Admins.' };
    jiraState = 'Restricted';
  } else {
    jiraStatus = { connected: null, error: errorOf(jiraResult) || 'Jira status unavailable' };
    jiraState = 'Unavailable';
  }

  let githubStatus;
  let githubState;
  if (githubResult.status === 'fulfilled') {
    const status = unwrapPayload(githubResult.value) || {};
    githubStatus = { ...status, connected: Boolean(status.connected), suspended: Boolean(status.suspended) };
    githubState = githubStatus.suspended ? 'Suspended' : githubStatus.connected ? 'Connected' : 'Not connected';
  } else if (githubResult.reason?.status === 404) {
    githubStatus = { connected: false, suspended: false };
    githubState = 'Not connected';
  } else if (githubResult.reason?.status === 403) {
    githubStatus = { connected: null, error: 'GitHub connection status is restricted to company Admins.' };
    githubState = 'Restricted';
  } else {
    githubStatus = { connected: null, error: errorOf(githubResult) || 'GitHub status unavailable' };
    githubState = 'Unavailable';
  }

  const resourceStates = {
    projects: statusOf(projectsResult),
    clients: statusOf(clientsResult),
    employees: statusOf(employeesResult),
    knowledge: statusOf(sourcesResult),
    jira: jiraState,
    github: githubState,
  };
  const resourceErrors = {
    projects: errorOf(projectsResult),
    clients: errorOf(clientsResult),
    employees: errorOf(employeesResult),
    knowledge: errorOf(sourcesResult),
  };
  const failures = Object.entries(resourceErrors)
    .filter(([, message]) => Boolean(message))
    .map(([resource, message]) => `${resource}: ${message}`);

  return { projects, clients, employees, knowledgeSources, jiraStatus, githubStatus, resourceStates, resourceErrors, failures };
}

export async function connectJira() {
  return unwrapPayload(await request(ENDPOINTS.jiraConnect));
}

export async function getPendingJiraSites(pendingId) {
  const query = new URLSearchParams({ pendingId });
  return unwrapArray(await request(`${ENDPOINTS.jiraPendingSites}?${query.toString()}`));
}

export function completeJiraConnection(pendingId, cloudId) {
  return request(ENDPOINTS.jiraComplete, {
    method: 'POST',
    body: { pendingId, cloudId },
  });
}

export function startJiraSync() {
  return request(ENDPOINTS.jiraSync, { method: 'POST' });
}

export function createProject(payload) {
  return request(ENDPOINTS.projects, { method: 'POST', body: payload });
}

export function createClient(payload) {
  return request(ENDPOINTS.clients, { method: 'POST', body: payload });
}

export function createMeetingNote(payload) {
  return request(ENDPOINTS.knowledgeSources, { method: 'POST', body: payload });
}

export async function getKnowledgeSource(sourceId, version) {
  const query = version ? `?version=${encodeURIComponent(version)}` : '';
  return unwrapPayload(await request(`${ENDPOINTS.knowledgeSource(sourceId)}${query}`));
}

export function retryKnowledgeExtraction(sourceId, version) {
  return request(`${ENDPOINTS.knowledgeSource(sourceId)}/versions/${encodeURIComponent(version)}/retry`, { method: 'POST' });
}

export function reviewKnowledgeSource(sourceId, version, decisions, publish = true) {
  return request(`${ENDPOINTS.knowledgeSource(sourceId)}/versions/${encodeURIComponent(version)}/review`, {
    method: 'POST', body: { decisions, publish },
  });
}

export function connectGitHub() { return request(ENDPOINTS.githubConnect); }
export async function getGitHubPending(completionId) { return unwrapPayload(await request(ENDPOINTS.githubPending(completionId))); }
export function completeGitHubConnection(payload) { return request(ENDPOINTS.githubComplete, { method: 'POST', body: payload }); }
export async function getGitHubRepositories() { return unwrapArray(await request(ENDPOINTS.githubRepositories)); }
export async function getGitHubProjectStatus(projectId) { return unwrapPayload(await request(ENDPOINTS.githubProject(projectId))); }
export function mapGitHubRepository(projectId, repositoryId) { return request(ENDPOINTS.githubProjectRepository(projectId), { method: 'PUT', body: { repositoryId } }); }
export function unmapGitHubRepository(projectId) { return request(ENDPOINTS.githubProjectRepository(projectId), { method: 'DELETE' }); }
export function syncGitHubProject(projectId) { return request(ENDPOINTS.githubProjectSync(projectId), { method: 'POST' }); }

export function listConversations() { return request(ENDPOINTS.assistantConversations); }
export function getConversationMessages(conversationId) { return request(ENDPOINTS.assistantMessages(conversationId)); }
// The API allows the AI provider up to 90 seconds; leave headroom for retrieval and persistence.
export function askAssistant(payload) { return request(ENDPOINTS.assistantAsk, { method: 'POST', body: payload, timeoutMs: 100000 }); }
export function deleteConversation(conversationId) { return request(ENDPOINTS.assistantConversation(conversationId), { method: 'DELETE' }); }
