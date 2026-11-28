import { API_BASE_URL } from '../config/api.js';
import { request, refreshSession } from './apiClient.js';
import { tokenStore } from './tokenStore.js';

const BASE = '/api/meetings';
const own = (value, key) => value != null && Object.prototype.hasOwnProperty.call(value, key);
const first = (value, ...keys) => {
  for (const key of keys) if (own(value, key) && value[key] != null) return value[key];
  return undefined;
};

/** Unwrap the response envelopes used by the API client and older controller wrappers. */
export function unwrapMeetingResponse(value) {
  let current = value;
  for (let depth = 0; depth < 3; depth += 1) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) break;
    const next = first(current, 'data', 'result', 'payload');
    if (next === undefined || next === current) break;
    current = next;
  }
  return current;
}

function normalizeDraft(raw = {}) {
  return {
    ...raw,
    id: first(raw, 'id', 'Id', 'uid', 'UID'),
    title: first(raw, 'title', 'Title') || 'Jira draft',
    description: first(raw, 'description', 'Description') || '',
    acceptance: first(raw, 'acceptance', 'Acceptance') || [],
    subtasks: first(raw, 'subtasks', 'Subtasks') || [],
    status: String(first(raw, 'status', 'Status') || 'pending').toLowerCase(),
    jiraKey: first(raw, 'jiraKey', 'JiraKey', 'jira_key') || null,
    jiraLabel: first(raw, 'jiraLabel', 'JiraLabel', 'jira_label') || null,
    stale: Boolean(first(raw, 'stale', 'Stale')),
    estimateBasedOn: first(raw, 'estimateBasedOn', 'EstimateBasedOn', 'estimate_based_on') || [],
  };
}

function normalizeItem(raw = {}) {
  const drafts = first(raw, 'drafts', 'Drafts') || [];
  return {
    ...raw,
    id: first(raw, 'id', 'Id', 'uid', 'UID'),
    type: first(raw, 'type', 'Type') || 'requirement',
    text: first(raw, 'text', 'Text') || '',
    evidence: first(raw, 'evidence', 'Evidence') || '',
    evidenceLines: first(raw, 'evidenceLines', 'EvidenceLines', 'evidence_lines') || [],
    status: String(first(raw, 'status', 'Status') || 'pending').toLowerCase(),
    needsReview: Boolean(first(raw, 'needsReview', 'NeedsReview', 'needs_review')),
    relatedKeys: first(raw, 'relatedKeys', 'RelatedKeys', 'related_keys') || [],
    jiraLinks: first(raw, 'jiraLinks', 'JiraLinks', 'jira_links') || [],
    suggestedLinks: first(raw, 'suggestedLinks', 'SuggestedLinks', 'suggested_links') || [],
    acceptanceSaid: first(raw, 'acceptanceSaid', 'AcceptanceSaid', 'acceptance_said') || [],
    acceptanceSuggested: first(raw, 'acceptanceSuggested', 'AcceptanceSuggested', 'acceptance_suggested') || [],
    drafts: Array.isArray(drafts) ? drafts.map(normalizeDraft) : [],
  };
}

/** Convert camelCase, PascalCase or snake_case source responses to the React view model. */
export function normalizeMeeting(value) {
  const raw = unwrapMeetingResponse(value);
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return raw;
  const scopeRaw = first(raw, 'scope', 'Scope') || {};
  const items = first(raw, 'items', 'Items') || [];
  const sourceId = first(raw, 'sourceId', 'SourceId', 'source_id', 'id', 'Id');
  return {
    ...raw,
    sourceId,
    sourceType: first(raw, 'sourceType', 'SourceType', 'source_type') || 'note',
    title: first(raw, 'title', 'Title') || '',
    meetingDate: first(raw, 'meetingDate', 'MeetingDate', 'meeting_date') || null,
    projectKey: first(raw, 'projectKey', 'ProjectKey', 'project_key') || '',
    linkedSourceId: first(raw, 'linkedSourceId', 'LinkedSourceId', 'linked_source_id') || null,
    status: String(first(raw, 'status', 'Status') || 'unknown').toLowerCase(),
    error: first(raw, 'error', 'Error') || null,
    analysisError: first(raw, 'analysisError', 'AnalysisError', 'analysis_error') || null,
    summary: first(raw, 'summary', 'Summary') || '',
    notes: first(raw, 'notes', 'Notes') || '',
    rejectedItems: Number(first(raw, 'rejectedItems', 'RejectedItems', 'rejected_items') || 0),
    unresolvedReferences: first(raw, 'unresolvedReferences', 'UnresolvedReferences', 'unresolved_references') || [],
    runInfo: first(raw, 'runInfo', 'RunInfo', 'run_info') || null,
    items: Array.isArray(items) ? items.map(normalizeItem) : [],
    scope: {
      ...scopeRaw,
      agreed: first(scopeRaw, 'agreed', 'Agreed') || [],
      outOfScope: first(scopeRaw, 'outOfScope', 'OutOfScope', 'out_of_scope') || [],
      open: first(scopeRaw, 'open', 'Open') || [],
    },
  };
}

function normalizeRows(value, keys = []) {
  const data = unwrapMeetingResponse(value);
  if (Array.isArray(data)) return data;
  for (const key of [...keys, 'items', 'results', 'rows']) {
    const pascalKey = key ? key[0].toUpperCase() + key.slice(1) : '';
    const rows = first(data, key, pascalKey);
    if (Array.isArray(rows)) return rows;
  }
  return [];
}

function normalizeMeetingListRow(raw = {}) {
  return {
    ...raw,
    sourceId: first(raw, 'sourceId', 'SourceId', 'source_id', 'id', 'Id'),
    sourceType: first(raw, 'sourceType', 'SourceType', 'source_type') || 'note',
    title: first(raw, 'title', 'Title') || '',
    meetingDate: first(raw, 'meetingDate', 'MeetingDate', 'meeting_date') || null,
    projectKey: first(raw, 'projectKey', 'ProjectKey', 'project_key') || '',
    linkedSourceId: first(raw, 'linkedSourceId', 'LinkedSourceId', 'linked_source_id') || null,
    status: String(first(raw, 'status', 'Status') || 'unknown').toLowerCase(),
    error: first(raw, 'error', 'Error') || null,
    // The project-list endpoint returns item counts, unlike GET /{id}, which returns item arrays.
    items: Number(first(raw, 'items', 'Items', 'itemCount', 'item_count') || 0),
    toReview: Number(first(raw, 'toReview', 'ToReview', 'to_review') || 0),
  };
}

function normalizeRequirement(raw = {}) {
  return {
    ...raw,
    id: first(raw, 'id', 'Id', 'uid', 'UID'),
    text: first(raw, 'text', 'Text') || '',
    status: String(first(raw, 'status', 'Status') || 'unknown').toLowerCase(),
    updatedAt: first(raw, 'updatedAt', 'UpdatedAt', 'updated_at') || null,
    changes: first(raw, 'changes', 'Changes') || [],
  };
}

function normalizeOpenQuestion(raw = {}) {
  return {
    ...raw,
    id: first(raw, 'id', 'Id', 'uid', 'UID'),
    text: first(raw, 'text', 'Text') || '',
    quote: first(raw, 'quote', 'Quote') || '',
    meeting: first(raw, 'meeting', 'Meeting', 'title', 'Title') || '',
    meetingDate: first(raw, 'meetingDate', 'MeetingDate', 'meeting_date') || null,
  };
}

async function jsonRequest(path, options = {}) {
  return unwrapMeetingResponse(await request(path, options));
}

function idPath(id) {
  if (id === undefined || id === null || String(id).trim() === '') {
    throw new Error('A meeting ID is required for this operation.');
  }
  return `${BASE}/${encodeURIComponent(String(id))}`;
}

function livePath(id) {
  if (id === undefined || id === null || String(id).trim() === '') {
    throw new Error('A live-session ID is required for this operation.');
  }
  return `${BASE}/live/${encodeURIComponent(String(id))}`;
}

export async function getMeetingPermissions() {
  const response = await jsonRequest(`${BASE}/permissions`);
  const permissions = first(response, 'permissions', 'Permissions') || [];
  return {
    ...response,
    permissions: Array.isArray(permissions) ? permissions : [],
    assistant: first(response, 'assistant', 'Assistant') || null,
  };
}

export async function createAIMeeting(payload) {
  const response = await jsonRequest(BASE, { method: 'POST', body: payload, timeoutMs: 120000 });
  return normalizeMeeting(response);
}

export async function getAIMeeting(sourceId) {
  return normalizeMeeting(await jsonRequest(idPath(sourceId), { timeoutMs: 60000 }));
}

export async function listAIMeetings(projectId, status = '') {
  if (!projectId) throw new Error('Choose a project before loading its meetings.');
  const query = new URLSearchParams({ projectKey: String(projectId) });
  if (status) query.set('status', status);
  return normalizeRows(await jsonRequest(`${BASE}?${query.toString()}`), ['meetings', 'sources'])
    .map(normalizeMeetingListRow);
}

export async function retryAIMeeting(sourceId) {
  return normalizeMeeting(await jsonRequest(`${idPath(sourceId)}/retry`, { method: 'POST', timeoutMs: 60000 }));
}

export async function deleteAIMeeting(sourceId) {
  return jsonRequest(idPath(sourceId), { method: 'DELETE', timeoutMs: 60000 });
}

export async function getAIMeetingDocument(sourceId) {
  return jsonRequest(`${idPath(sourceId)}/document`, { timeoutMs: 60000 });
}

export async function saveAIMeetingDocument(sourceId, text) {
  return jsonRequest(`${idPath(sourceId)}/document`, {
    method: 'PUT', body: { text }, timeoutMs: 60000,
  });
}

export async function rewriteAIMeetingDocument(sourceId, instruction, part = null) {
  return jsonRequest(`${idPath(sourceId)}/document/rewrite`, {
    method: 'POST', body: { instruction, part }, timeoutMs: 120000,
  });
}

/** Approve/delete item and draft IDs; the backend owns the final approval transaction. */
export async function reviewAIMeeting(sourceId, { approve = [], remove = [], links = {} } = {}) {
  return normalizeMeeting(await jsonRequest(`${idPath(sourceId)}/review`, {
    method: 'POST', body: { approve, delete: remove, links }, timeoutMs: 60000,
  }));
}

export async function getProjectRequirementHistory(projectId, query = '') {
  if (!projectId) throw new Error('Choose a project before loading requirement history.');
  const params = new URLSearchParams();
  if (query.trim()) params.set('q', query.trim());
  const suffix = params.toString() ? `?${params.toString()}` : '';
  return normalizeRows(await jsonRequest(`${BASE}/projects/${encodeURIComponent(projectId)}/requirements${suffix}`), ['requirements'])
    .map(normalizeRequirement);
}

export async function editProjectRequirement(requirementId, text) {
  return jsonRequest(`${BASE}/requirements/${encodeURIComponent(requirementId)}`, {
    method: 'PATCH', body: { text }, timeoutMs: 60000,
  });
}

export async function getProjectOpenQuestions(projectId) {
  if (!projectId) throw new Error('Choose a project before loading open questions.');
  return normalizeRows(await jsonRequest(`${BASE}/projects/${encodeURIComponent(projectId)}/open-questions`), ['openQuestions', 'questions'])
    .map(normalizeOpenQuestion);
}

export async function startLiveMeeting(projectKey, title = null) {
  if (!projectKey) throw new Error('Choose a project before starting a live meeting.');
  return jsonRequest(`${BASE}/live`, { method: 'POST', body: { projectKey, title }, timeoutMs: 60000 });
}

export async function getLiveMeeting(sessionId) {
  return jsonRequest(livePath(sessionId), { timeoutMs: 60000 });
}

export async function assistLiveMeeting(sessionId, { transcript, question = null, dismiss = [] }) {
  return jsonRequest(`${livePath(sessionId)}/assist`, {
    method: 'POST', body: { transcript, question, dismiss }, timeoutMs: 120000,
  });
}

export async function wrapUpLiveMeeting(sessionId, transcript) {
  return jsonRequest(`${livePath(sessionId)}/wrap-up`, {
    method: 'POST', body: { transcript }, timeoutMs: 120000,
  });
}

export async function endLiveMeeting(sessionId, { transcript = null, meetingDate = null } = {}) {
  return jsonRequest(`${livePath(sessionId)}/end`, {
    method: 'POST', body: { transcript, meetingDate }, timeoutMs: 120000,
  });
}

export async function deleteLiveMeeting(sessionId) {
  return jsonRequest(livePath(sessionId), { method: 'DELETE', timeoutMs: 60000 });
}

export async function publishMeetingDraft(sourceId, draftId) {
  if (!draftId) throw new Error('A Jira draft ID is required for publishing.');
  return jsonRequest(`${idPath(sourceId)}/drafts/${encodeURIComponent(String(draftId))}/publish`, {
    method: 'POST', timeoutMs: 120000,
  });
}

export async function downloadAIMeetingPdf(sourceId) {
  const path = `${idPath(sourceId)}/requirements.pdf`;
  const send = async () => {
    const token = tokenStore.get();
    return fetch(`${API_BASE_URL}${path}`, {
      headers: { Accept: 'application/pdf', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      credentials: 'omit', cache: 'no-store', redirect: 'error',
    });
  };
  let response = await send();
  if (response.status === 401) {
    await refreshSession();
    response = await send();
  }
  if (!response.ok) {
    const body = await response.text().catch(() => '');
    let message = body || `PDF export failed (${response.status}).`;
    try {
      const parsed = JSON.parse(body);
      message = parsed.detail || parsed.message || parsed.title || message;
    } catch { /* A plain-text error is already useful. */ }
    throw new Error(message);
  }
  const blob = await response.blob();
  if (!blob.size) throw new Error('The PDF endpoint returned an empty file.');
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `syntrace-meeting-${String(sourceId).replace(/[^a-zA-Z0-9_-]/g, '')}.pdf`;
  anchor.style.display = 'none';
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
}
