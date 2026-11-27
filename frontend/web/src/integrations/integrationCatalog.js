/** Canonical integration metadata used by the Integrations workspace. */
export const integrationCatalog = Object.freeze([
  { id: 'github', name: 'GitHub', category: 'Source control', connection: 'backend-oauth' },
  { id: 'slack', name: 'Slack', category: 'Team communication', connection: 'backend-required' },
  { id: 'jira', name: 'Jira', category: 'Project delivery', connection: 'backend-oauth' },
  { id: 'meeting-notes', name: 'Meeting Notes', category: 'AI knowledge capture', connection: 'knowledge-api' },
]);
