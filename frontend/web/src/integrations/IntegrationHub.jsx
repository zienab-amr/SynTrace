import './integrations.css';

function Status({ state, detail }) {
  const normalized = String(state || 'Unknown').toLowerCase();
  const tone = normalized.includes('connected') && !normalized.includes('not connected') ? 'connected'
    : normalized.includes('ready') || normalized.includes('available') ? 'ready'
      : normalized.includes('required') || normalized.includes('unavailable') || normalized.includes('restricted') ? 'attention' : 'neutral';
  return <span className={`st-integration-status st-integration-status--${tone}`} title={detail || state}>
    <i aria-hidden="true" />{state || 'Status unavailable'}
  </span>;
}

function BrandMark({ type }) {
  if (type === 'github') return <span className="st-integration-brand st-integration-brand--github" aria-hidden="true"><svg viewBox="0 0 24 24"><path fill="currentColor" d="M12 .9a11.1 11.1 0 0 0-3.51 21.63c.56.1.76-.24.76-.54v-2.08c-3.1.68-3.76-1.32-3.76-1.32-.5-1.29-1.24-1.63-1.24-1.63-1.01-.69.08-.68.08-.68 1.12.08 1.71 1.15 1.71 1.15 1 .1.76 2.16 3.2 1.62.1-.72.39-1.21.7-1.49-2.48-.28-5.09-1.24-5.09-5.53 0-1.22.44-2.22 1.15-3-.12-.28-.5-1.42.11-2.96 0 0 .94-.3 3.06 1.15a10.65 10.65 0 0 1 5.57 0c2.12-1.44 3.06-1.15 3.06-1.15.61 1.54.23 2.68.11 2.96.72.78 1.15 1.78 1.15 3 0 4.3-2.62 5.24-5.11 5.52.4.35.75 1.03.75 2.08v3.09c0 .3.2.65.77.54A11.1 11.1 0 0 0 12 .9Z"/></svg></span>;
  if (type === 'slack') return <span className="st-integration-brand st-integration-brand--slack" aria-hidden="true"><svg viewBox="0 0 24 24"><path fill="#36C5F0" d="M9.1 1.5a2 2 0 1 0 0 4h2v-2a2 2 0 0 0-2-2Z"/><path fill="#2EB67D" d="M14.9 1.5a2 2 0 1 0-4 0v2h2a2 2 0 0 0 2-2Z"/><path fill="#E01E5A" d="M22.5 9.1a2 2 0 1 0-4 0v2h2a2 2 0 0 0 2-2Z"/><path fill="#ECB22E" d="M22.5 14.9a2 2 0 1 0 0-4h-2v2a2 2 0 0 0 2 2Z"/><path fill="#36C5F0" d="M14.9 22.5a2 2 0 1 0 0-4h-2v2a2 2 0 0 0 2 2Z"/><path fill="#2EB67D" d="M9.1 22.5a2 2 0 1 0 4 0v-2h-2a2 2 0 0 0-2 2Z"/><path fill="#E01E5A" d="M1.5 14.9a2 2 0 1 0 4 0v-2h-2a2 2 0 0 0-2 2Z"/><path fill="#ECB22E" d="M1.5 9.1a2 2 0 1 0 0 4h2v-2a2 2 0 0 0-2-2Z"/></svg></span>;
  if (type === 'jira') return <span className="st-integration-brand st-integration-brand--jira" aria-hidden="true"><svg viewBox="0 0 24 24"><path fill="currentColor" d="M11.8 2 3 10.8a1.7 1.7 0 0 0 0 2.4l8.8 8.8 8.8-8.8a1.7 1.7 0 0 0 0-2.4L11.8 2Zm0 5.1 4.9 4.9-4.9 4.9-4.9-4.9 4.9-4.9Z"/></svg></span>;
  return <span className="st-integration-brand st-integration-brand--notes" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M5 3.5h9l5 5V20a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 20V3.5Z"/><path d="M14 3.5V9h5M8 13h8M8 17h8"/></svg></span>;
}

function IntegrationCard({ type, eyebrow, title, description, state, detail, action, actionLabel, busy, secondary, secondaryLabel, disabled, note }) {
  return <article className={`st-integration-card st-integration-card--${type}`}>
    <div className="st-integration-card__top"><BrandMark type={type}/><Status state={state} detail={detail}/></div>
    <div className="st-integration-card__copy"><span className="st-section-label">{eyebrow}</span><h2>{title}</h2><p>{description}</p></div>
    {note && <div className="st-integration-note">{note}</div>}
    <div className="st-integration-card__footer">
      <button type="button" className="st-integration-primary" onClick={action} disabled={disabled || busy}>{busy ? 'Please wait…' : actionLabel}</button>
      {secondary && <button type="button" className="st-integration-secondary" onClick={secondary} disabled={disabled}>{secondaryLabel}</button>}
    </div>
  </article>;
}

export default function IntegrationHub({ githubStatus, jiraStatus, githubBusy, jiraBusy, isAdmin, meetingCount, onConnectGitHub, onManageGitHub, onConnectJira, onSyncJira, onCreateMeeting, onViewMeetings, onSlackConnect }) {
  const githubConnected = githubStatus?.connected === true && !githubStatus?.suspended;
  const jiraConnected = jiraStatus?.connected === true;
  const githubState = githubStatus?.suspended ? 'Installation suspended' : githubConnected ? 'Connected' : githubStatus?.connected === null ? 'Status unavailable' : 'Not connected';
  const jiraState = jiraConnected ? 'Connected' : jiraStatus?.connected === null ? 'Status unavailable' : 'Not connected';

  return <div className="st-integrations-view st-view-enter">
    <header className="st-integrations-heading">
      <div><div className="st-breadcrumb"><span>Workspace</span><b>/</b><strong>Integrations</strong></div><span className="st-eyebrow">CONNECTED WORKFLOW</span><h1>Integrations</h1><p>Connect the tools your team already uses and bring project context into SynTrace.</p></div>
      <div className="st-integrations-summary"><span className="st-integrations-summary__icon"><svg viewBox="0 0 24 24"><path d="M8 7V3m8 4V3M6 7h12v4a6 6 0 0 1-12 0V7Zm6 10v4"/></svg></span><span><strong>Workspace connections</strong><small>Secure, company-scoped integrations</small></span></div>
    </header>

    <section className="st-integrations-intro">
      <div><span className="st-section-label">INTEGRATION DIRECTORY</span><h2>Bring your workflow together</h2><p>Authorize a service, choose what SynTrace can access, then manage synchronization from one place.</p></div>
      <div className="st-integrations-intro__meta"><span><i/> OAuth-based connections</span><span><i/> Project-level access controls</span></div>
    </section>

    <div className="st-integrations-grid">
      <IntegrationCard type="github" eyebrow="SOURCE CONTROL" title="GitHub" description="Connect your GitHub organization, select repositories for each project, and sync commits and pull requests into project context." state={githubState} detail={githubStatus?.accountLogin || githubStatus?.error} action={githubConnected ? onManageGitHub : onConnectGitHub} actionLabel={githubConnected ? 'Manage repositories' : 'Connect GitHub'} busy={githubBusy} disabled={!isAdmin || githubStatus?.suspended} note={githubStatus?.accountLogin ? `Connected account · ${githubStatus.accountLogin}` : 'GitHub App authorization · repository permissions are selected during installation'} />

      <IntegrationCard type="slack" eyebrow="TEAM COMMUNICATION" title="Slack" description="Bring project conversations, decisions and team updates into a shared workspace context." state="Backend setup required" detail="Slack OAuth endpoints are not currently available" action={onSlackConnect} actionLabel="Connect Slack" note="The UI is ready for the connection flow. A secure Slack OAuth callback and token-storage API must be added to the backend before authorization can complete." />

      <IntegrationCard type="jira" eyebrow="PROJECT DELIVERY" title="Jira" description="Connect your Jira Cloud site and keep your SynTrace workspace aligned with delivery activity." state={jiraState} detail={jiraStatus?.error} action={jiraConnected ? onSyncJira : onConnectJira} actionLabel={jiraConnected ? 'Sync Jira' : 'Connect Jira'} busy={jiraBusy} disabled={!isAdmin} note={jiraStatus?.siteUrl || jiraStatus?.cloudName || 'Atlassian OAuth · company-level Jira site connection'} />

      <IntegrationCard type="notes" eyebrow="AI KNOWLEDGE CAPTURE" title="Meeting Notes" description="Save original meeting notes, let the AI extract decisions and action items, then review and publish approved evidence." state={`${meetingCount} available`} detail="Knowledge Sources API" action={onCreateMeeting} actionLabel="New meeting note" secondary={onViewMeetings} secondaryLabel="View notes" note="AI extraction is processed by the knowledge worker. Review and publication follow your workspace permissions." />
    </div>

    <footer className="st-integrations-footnote"><span className="st-integrations-footnote__lock"><svg viewBox="0 0 24 24"><rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg></span><p><strong>Your connections stay under your control.</strong> SynTrace uses backend-managed authorization and project permissions. Tokens are never stored in browser code.</p></footer>
  </div>;
}
