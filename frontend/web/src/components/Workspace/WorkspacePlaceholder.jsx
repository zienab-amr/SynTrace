import { assetUrl } from '../../lib/assetUrl.js';
import { useEffect, useMemo, useRef, useState } from 'react';
import ThemeToggle from '../common/ThemeToggle.jsx';
import { useAuth } from '../../context/AuthContext.jsx';
import { navigate } from '../../router/router.jsx';
import ChatPage from '../Chat/ChatPage.jsx';
import MeetingAI from './MeetingAI.jsx';
import { getWorkspaceSnapshot, createProject, createClient, createMeetingNote, getKnowledgeSource, retryKnowledgeExtraction, reviewKnowledgeSource } from '../../services/workspaceService.js';
import { connectJira, getPendingJiraSites, completeJiraConnection, startJiraSync, connectGitHub, getGitHubPending, completeGitHubConnection, getGitHubRepositories, getGitHubProjectStatus, mapGitHubRepository, unmapGitHubRepository, syncGitHubProject } from '../../integrations/integrationService.js';
import WorkspaceCreateDialog from './WorkspaceCreateDialog.jsx';
import IntegrationHub from '../../integrations/IntegrationHub.jsx';
import './workspace-dashboard.css';

function Icon({ name, size = 18, strokeWidth = 1.75 }) {
  const common = { fill: 'none', stroke: 'currentColor', strokeWidth, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const shapes = {
    grid: <><rect x="4" y="4" width="6" height="6" rx="1.3"/><rect x="14" y="4" width="6" height="6" rx="1.3"/><rect x="4" y="14" width="6" height="6" rx="1.3"/><rect x="14" y="14" width="6" height="6" rx="1.3"/></>,
    chat: <><path d="M20 11.5a7.5 7.5 0 0 1-7.5 7.5H6l-3 2v-6.5A7.5 7.5 0 1 1 20 11.5Z"/><path d="M8 11h8M8 14h5"/></>,
    graph: <><circle cx="5" cy="6" r="2"/><circle cx="19" cy="6" r="2"/><circle cx="12" cy="18" r="2"/><path d="m7 7 4 9M17 7l-4 9M7 6h10"/></>,
    folder: <><path d="M3 7.5a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v8.8a2.2 2.2 0 0 1-2.2 2.2H5.2A2.2 2.2 0 0 1 3 18.3Z"/><path d="M3.5 9h17"/></>,
    tasks: <><rect x="4" y="4" width="16" height="16" rx="3"/><path d="m8 12 2.5 2.5L16 9"/></>,
    calendar: <><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M7 3v4M17 3v4M3 9.5h18M7.5 13h3M14 13h3M7.5 17h3"/></>,
    users: <><path d="M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20M10 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7ZM17 4.5a3.5 3.5 0 0 1 0 6.8M20 20v-1.5a3.5 3.5 0 0 0-2.5-3.35"/></>,
    settings: <><circle cx="12" cy="12" r="3"/><path d="m19.4 15 .1.1a1.7 1.7 0 0 1-2.4 2.4l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a1.7 1.7 0 0 1-3.4 0v-.2a1.7 1.7 0 0 0-2.9-1.2l-.1.1a1.7 1.7 0 1 1-2.4-2.4l.1-.1a1.7 1.7 0 0 0-1.2-2.9H4a1.7 1.7 0 0 1 0-3.4h.2a1.7 1.7 0 0 0 1.2-2.9l-.1-.1a1.7 1.7 0 1 1 2.4-2.4l.1.1a1.7 1.7 0 0 0 2.9-1.2V2a1.7 1.7 0 0 1 3.4 0v.2a1.7 1.7 0 0 0 2.9 1.2l.1-.1a1.7 1.7 0 1 1 2.4 2.4l-.1.1a1.7 1.7 0 0 0 1.2 2.9h.2a1.7 1.7 0 0 1 0 3.4h-.2a1.7 1.7 0 0 0-1.2 2.9Z"/></>,
    help: <><circle cx="12" cy="12" r="9"/><path d="M9.6 9a2.5 2.5 0 1 1 4.4 1.6c-1.2 1.3-2 1.5-2 3.1M12 17h.01"/></>,
    search: <><circle cx="10.8" cy="10.8" r="6.8"/><path d="m16 16 4.5 4.5"/></>,
    bell: <><path d="M18 9a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/></>,
    chevron: <path d="m8 10 4 4 4-4"/>,
    arrow: <><path d="M5 12h14M13 6l6 6-6 6"/></>,
    more: <><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    check: <path d="m5 12 4.2 4.2L19 6.5"/>,
    alert: <><path d="M10.3 4.5 2.9 17.2A2 2 0 0 0 4.6 20h14.8a2 2 0 0 0 1.7-2.8L13.7 4.5a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 16.5h.01"/></>,
    spark: <><path d="m12 3 1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3Z"/><path d="m19 15 .9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9L19 15Z"/></>,
    sliders: <><path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="2" fill="currentColor" stroke="none"/><circle cx="11" cy="18" r="2" fill="currentColor" stroke="none"/></>,
    plus: <path d="M12 5v14M5 12h14"/>,
    logout: <><path d="M10 17l5-5-5-5M15 12H3"/><path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6"/></>,
    book: <><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v17H6.5A2.5 2.5 0 0 0 4 22Z"/><path d="M4 5.5v14A2.5 2.5 0 0 1 6.5 17H20"/></>,
    info: <><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></>,
    target: <><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/></>,
    filter: <><path d="M4 5h16l-6.2 7.1v5.2l-3.6 1.8v-7Z"/></>,
    close: <><path d="m6 6 12 12M18 6 6 18"/></>,
    link: <><path d="M10 13a5 5 0 0 0 7.1 0l2-2A5 5 0 0 0 12 3.9l-1.1 1.1"/><path d="M14 11a5 5 0 0 0-7.1 0l-2 2A5 5 0 0 0 12 20.1l1.1-1.1"/></>,
    plug: <><path d="M9 7V3M15 7V3M7 7h10v4a5 5 0 0 1-10 0V7ZM12 16v5"/><path d="M5 7h14"/></>,
    refresh: <><path d="M20 7v5h-5M4 17v-5h5"/><path d="M5.6 9A7 7 0 0 1 18 6.5L20 12M4 12l2 5.5A7 7 0 0 0 18.4 15"/></>,
    database: <><ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v7c0 1.7 3.6 3 8 3s8-1.3 8-3V5M4 12v7c0 1.7 3.6 3 8 3s8-1.3 8-3v-7"/></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" {...common}>{shapes[name] || shapes.grid}</svg>;
}


function initialsFor(user) {
  const value = user?.name || user?.email?.split('@')[0] || 'ST';
  return value.split(/[\s._-]+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
}

function read(value, camel, pascal) { return value?.[camel] ?? value?.[pascal]; }
function projectIdOf(project) { return String(read(project, 'projectId', 'ProjectId') ?? read(project, 'id', 'Id') ?? ''); }
function clientIdOf(client) { return String(read(client, 'clientId', 'ClientId') ?? read(client, 'id', 'Id') ?? ''); }
function sourceIdOf(source) { return String(read(source, 'id', 'Id') ?? ''); }
function sourceKind(source) { return String(read(source, 'kind', 'Kind') ?? 'Knowledge source'); }
function sourceStatus(source) { return String(read(source, 'status', 'Status') ?? 'Unknown'); }
function projectLabel(project) { return read(project, 'projectName', 'ProjectName') || read(project, 'name', 'Name') || projectIdOf(project); }
function clientLabel(client) { return read(client, 'clientName', 'ClientName') || read(client, 'name', 'Name') || clientIdOf(client); }
function toneForIndex(index) { return ['blue', 'mint', 'amber'][index % 3]; }
function formatDate(value) {
  if (!value) return 'Date not supplied';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'Date not supplied' : date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}
function statusText(value) {
  if (!value) return 'Unknown';
  return String(value).replace(/([a-z])([A-Z])/g, '$1 $2').replaceAll('_', ' ');
}

function buildGraphData(projects, clients, sources) {
  const nodes = [];
  const edges = [];
  const clientById = new Map(clients.map((client) => [clientIdOf(client), client]));
  const projectById = new Map(projects.map((project) => [projectIdOf(project), project]));
  const usedClientIds = new Set(projects.map((project) => String(read(project, 'clientId', 'ClientId') || '')).filter(Boolean));
  sources.forEach((source) => {
    const clientId = String(read(source, 'clientId', 'ClientId') || '');
    if (clientId) usedClientIds.add(clientId);
  });
  const relevantClients = clients.filter((client) => usedClientIds.has(clientIdOf(client)));
  const graphHeight = Math.max(560, 118 + Math.max(relevantClients.length, projects.length, sources.length, 1) * 112);
  const yFor = (index) => 86 + index * 112;
  const clientPositions = new Map();
  const projectPositions = new Map();

  relevantClients.forEach((client, index) => {
    const clientId = clientIdOf(client);
    const id = `client:${clientId}`;
    const point = { x: 165, y: yFor(index) };
    clientPositions.set(clientId, point);
    nodes.push({
      id, ...point, group: 'Clients', type: 'Client', title: clientLabel(client),
      subtitle: read(client, 'email', 'Email') || clientId,
      tone: toneForIndex(index),
      description: `Client record ${clientId} returned by the authenticated Client API.`,
      source: 'GET /api/Client', related: [],
    });
  });

  projects.forEach((project, index) => {
    const projectId = projectIdOf(project);
    const id = `project:${projectId}`;
    const point = { x: 520, y: yFor(index) };
    projectPositions.set(projectId, point);
    const clientId = String(read(project, 'clientId', 'ClientId') || '');
    nodes.push({
      id, ...point, group: 'Work', type: 'Project', title: projectLabel(project),
      subtitle: clientById.has(clientId) ? clientLabel(clientById.get(clientId)) : (clientId || 'Client not linked'),
      tone: 'blue',
      description: read(project, 'description', 'Description') || 'Project record returned by the authenticated Projects API.',
      source: `GET /api/projects · ${projectId}`, related: [],
    });
    if (clientId && clientPositions.has(clientId)) {
      const targetId = `client:${clientId}`;
      nodes.find((node) => node.id === id)?.related.push(targetId);
      nodes.find((node) => node.id === targetId)?.related.push(id);
      const a = point; const b = clientPositions.get(clientId);
      edges.push({
        from: id, to: targetId, label: 'belongs to client',
        d: `M ${b.x + 86} ${b.y} C ${b.x + 205} ${b.y}, ${a.x - 205} ${a.y}, ${a.x - 86} ${a.y}`,
        lx: (a.x + b.x) / 2, ly: (a.y + b.y) / 2 - 9,
      });
    }
  });

  sources.forEach((source, index) => {
    const sourceId = sourceIdOf(source);
    const id = `source:${sourceId}`;
    const projectId = String(read(source, 'projectId', 'ProjectId') || '');
    const clientId = String(read(source, 'clientId', 'ClientId') || '');
    const point = { x: 875, y: yFor(index) };
    const kind = sourceKind(source);
    const title = read(source, 'title', 'Title') || `${statusText(kind)} source`;
    const status = sourceStatus(source);
    const type = kind === 'MeetingNotes' ? 'Meeting note' : kind === 'Documentation' ? 'Documentation' : kind === 'Requirements' ? 'Requirements' : 'Knowledge source';
    const project = projectById.get(projectId);
    nodes.push({
      id, ...point, group: 'Knowledge', type, title,
      subtitle: `${statusText(status)} · v${read(source, 'version', 'Version') ?? '—'}`,
      tone: 'mint',
      description: `Knowledge source ${sourceId}. Its relationship is based on the projectId/clientId returned by the backend.`,
      source: `GET /api/knowledge/sources · ${sourceId}`, related: [],
    });

    // A project-bound source must link to that exact accessible project. Do not
    // silently turn an inaccessible/missing project relationship into a client edge.
    const parentId = projectId
      ? (projectPositions.has(projectId) ? `project:${projectId}` : null)
      : (clientId && clientPositions.has(clientId) ? `client:${clientId}` : null);
    if (parentId) {
      nodes.find((node) => node.id === id)?.related.push(parentId);
      nodes.find((node) => node.id === parentId)?.related.push(id);
      const parent = nodes.find((node) => node.id === parentId);
      const a = parent; const b = nodes.find((node) => node.id === id);
      edges.push({
        from: id, to: parentId, label: project ? 'source for project' : 'client-level source',
        d: `M ${a.x + 86} ${a.y} C ${a.x + 205} ${a.y}, ${b.x - 205} ${b.y}, ${b.x - 86} ${b.y}`,
        lx: (a.x + b.x) / 2, ly: (a.y + b.y) / 2 - 9,
      });
    }
  });

  return { nodes, edges, graphHeight, totals: { clients: relevantClients.length, projects: projects.length, sources: sources.length } };
}

function WorkspaceGraph({ nodes, edges, graphHeight, totals, query, setQuery, searchRef, selectedId, setSelectedId, category, setCategory, zoom, setZoom }) {
  const visibleNodeIds = useMemo(() => {
    const term = query.trim().toLowerCase();
    return new Set(nodes.filter((node) => {
      const categoryMatch = category === 'All' || node.group === category;
      const queryMatch = !term || [node.title, node.type, node.subtitle, node.description].some((value) => String(value).toLowerCase().includes(term));
      return categoryMatch && queryMatch;
    }).map((node) => node.id));
  }, [nodes, query, category]);
  const selectedNode = visibleNodeIds.size ? (nodes.find((node) => node.id === selectedId && visibleNodeIds.has(node.id)) || nodes.find((node) => visibleNodeIds.has(node.id))) : null;
  const connectedNodes = selectedNode ? selectedNode.related.map((id) => nodes.find((node) => node.id === id)).filter(Boolean) : [];

  useEffect(() => {
    if (visibleNodeIds.size && !visibleNodeIds.has(selectedId)) setSelectedId([...visibleNodeIds][0]);
  }, [visibleNodeIds, selectedId, setSelectedId]);

  return (
    <section className="st-graph-view st-view-enter" aria-label="Knowledge Graph explorer">
      <div className="st-view-heading">
        <div><div className="st-breadcrumb"><span>Workspace</span><b>/</b><strong>Knowledge Graph</strong></div><span className="st-eyebrow">CONNECTED WORKSPACE RECORDS</span><h1>Knowledge Graph</h1><p>Explore relationships that are explicitly returned by your company-scoped project and knowledge APIs.</p></div>
        <span className="st-demo-tag"><i/> API-DERIVED RELATIONSHIPS</span>
      </div>
      <div className="st-graph-toolbar">
        <label className="st-graph-search"><Icon name="search" size={16}/><input ref={searchRef} value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search projects, clients and sources…" aria-label="Search graph"/><kbd>⌘ K</kbd></label>
        <div className="st-graph-categories" role="group" aria-label="Filter graph records">{['All', 'Work', 'Knowledge', 'Clients'].map((value) => <button type="button" key={value} className={category === value ? 'is-active' : ''} onClick={() => setCategory(value)}>{value}</button>)}</div>
        <div className="st-graph-zoom"><button type="button" aria-label="Zoom out" onClick={() => setZoom((value) => Math.max(.85, +(value - .1).toFixed(1)))}>−</button><span>{Math.round(zoom * 100)}%</span><button type="button" aria-label="Zoom in" onClick={() => setZoom((value) => Math.min(1.15, +(value + .1).toFixed(1)))}>+</button><button type="button" onClick={() => setZoom(1)}>Reset</button></div>
      </div>
      <div className="st-graph-summary"><div><span className="st-graph-summary__line st-graph-summary__line--source"/><strong>Clients</strong><small>Company client records</small></div><div><span className="st-graph-summary__line st-graph-summary__line--derived"/><strong>Knowledge sources</strong><small>Published or accessible source records</small></div><div><span className="st-graph-summary__line st-graph-summary__line--work"/><strong>Projects</strong><small>Accessible project records</small></div><span className="st-graph-summary__count">{visibleNodeIds.size} of {nodes.length} records shown</span></div>
      <div className="st-graph-layout">
        <div className="st-graph-canvas-wrap">
          <div className="st-graph-canvas-scroll">
            <div className="st-graph-canvas-inner" style={{ '--graph-zoom': zoom, height: `${graphHeight / zoom}px` }}>
              {nodes.length > 0 && <>
                <svg className="st-graph-edges" viewBox={`0 0 1040 ${graphHeight}`}  preserveAspectRatio="none" role="img" aria-label="Relationships derived from project, client and knowledge source records">
                  <defs><linearGradient id="st-edge-gradient" x1="0" x2="1"><stop offset="0%" stopColor="#31B9FF"/><stop offset="100%" stopColor="#20DDA8"/></linearGradient><marker id="st-edge-arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="context-stroke"/></marker></defs>
                  {edges.map((edge, index) => { const active = edge.from === selectedId || edge.to === selectedId; const visible = visibleNodeIds.has(edge.from) && visibleNodeIds.has(edge.to); return <g key={`${edge.from}-${edge.to}`} className={`st-graph-edge-group ${active ? 'is-active' : ''} ${visible ? '' : 'is-hidden'}`} style={{ '--edge-order': index }}><path className="st-graph-edge" d={edge.d} markerEnd="url(#st-edge-arrow)"/><text className="st-graph-edge-label" x={edge.lx} y={edge.ly}>{edge.label}</text></g>; })}
                </svg>
                {nodes.map((node, index) => { const visible = visibleNodeIds.has(node.id); const related = Boolean(selectedNode?.related.includes(node.id)); return <button type="button" key={node.id} className={`st-graph-node st-graph-node--${node.tone} ${selectedId === node.id ? 'is-selected' : ''} ${related ? 'is-related' : ''} ${visible ? '' : 'is-hidden'}`} style={{ left: `${(node.x / 1040) * 100}%`, top: `${(node.y / graphHeight) * 100}%`, '--node-order': index }} onClick={() => setSelectedId(node.id)} aria-pressed={selectedId === node.id}><span className="st-graph-node__type"><i/>{node.type}</span><strong>{node.title}</strong><small>{node.subtitle}</small></button>; })}
                {!visibleNodeIds.size && <div className="st-graph-empty"><strong>No matching workspace records</strong><span>Change the search term or select another record group.</span></div>}
                <span className="st-graph-axis st-graph-axis--left">CLIENT RECORDS</span><span className="st-graph-axis st-graph-axis--center">PROJECT CONTEXT</span><span className="st-graph-axis st-graph-axis--right">KNOWLEDGE SOURCES</span>
              </>}
              {!nodes.length && <div className="st-graph-empty st-graph-empty--static"><strong>No connected records are available yet</strong><span>Create or assign projects, clients and knowledge sources to reveal their actual relationships here.</span></div>}
            </div>
          </div>
          <div className="st-graph-canvas-footer"><span><i className="st-graph-legend-dot st-graph-legend-dot--source"/> Client</span><span><i className="st-graph-legend-dot st-graph-legend-dot--derived"/> Knowledge source</span><span><i className="st-graph-legend-dot st-graph-legend-dot--work"/> Project</span><small>Derived from GET /api/projects, /api/Client and /api/knowledge/sources · Not a direct Neo4j graph query</small></div>
        </div>
        {selectedNode ? <aside className="st-graph-inspector" aria-live="polite" key={selectedNode.id}>
          <div className="st-inspector-heading"><span>RECORD DETAILS</span><span className="st-inspector-count">{connectedNodes.length} links</span></div>
          <div className={`st-inspector-type st-inspector-type--${selectedNode.tone}`}><i/>{selectedNode.type}</div>
          <h2>{selectedNode.title}</h2><p className="st-inspector-subtitle">{selectedNode.subtitle}</p><p className="st-inspector-description">{selectedNode.description}</p>
          <div className="st-inspector-source"><Icon name="book" size={15}/><span><small>SOURCE / PROVENANCE</small><strong>{selectedNode.source}</strong></span></div>
          <div className="st-inspector-relations"><div className="st-inspector-relations__title">Connected records <span>{connectedNodes.length}</span></div>{connectedNodes.map((node) => <button type="button" key={node.id} onClick={() => setSelectedId(node.id)}><span className={`st-relation-mark st-relation-mark--${node.tone}`}/><span><small>{node.type}</small><strong>{node.title}</strong></span><Icon name="arrow" size={14}/></button>)}{!connectedNodes.length && <p className="st-graph-inspector-empty">No relationships were returned for this record.</p>}</div>
          <div className="st-inspector-note"><Icon name="info" size={14}/> Only explicit project/client/source IDs are connected here. Jira issue, sprint and employee relationships are not exposed by this API.</div>
        </aside> : <aside className="st-graph-inspector"><div className="st-inspector-heading">RECORD DETAILS</div><p className="st-graph-inspector-empty">Select a connected record to inspect it.</p></aside>}
      </div>
    </section>
  );
}

function WorkspaceStatus({ label, state, detail }) {
  const good = state === 'Connected' || state === 'Available';
  const warning = state === 'Not connected' || state === 'Restricted';
  return <div className="st-workspace-status-row"><span className={`st-status-dot ${good ? 'is-good' : warning ? 'is-warning' : ''}`}/><span><strong>{label}</strong><small>{detail}</small></span><b>{state}</b></div>;
}

function BarChart({ projects, sources }) {
  const values = projects.slice(0, 7).map((project, index) => {
    const id = projectIdOf(project);
    const count = sources.filter((source) => String(read(source, 'projectId', 'ProjectId') || '') === id).length;
    return { label: (projectLabel(project).split(/\s+/).map((part) => part[0]).join('').slice(0, 3) || `P${index + 1}`).toUpperCase(), count };
  });
  const max = Math.max(1, ...values.map((item) => item.count));
  return (
    <div className="st-bars" role="img" aria-label="Accessible knowledge sources by project">
      <div className="st-bars__scale"><span>{max}</span><span>{Math.ceil(max * .75)}</span><span>{Math.ceil(max * .5)}</span><span>{Math.ceil(max * .25)}</span><span>0</span></div>
      <div className="st-bars__plot"><div className="st-bars__grid"><i/><i/><i/><i/><i/></div><div className="st-bars__columns">
        {values.map((value, index) => <div className="st-bars__group" key={`${value.label}-${index}`} style={{ '--bar-index': index }}><div className="st-bars__pair"><span className="st-bars__bar st-bars__bar--opened" style={{ height: `${value.count === 0 ? 3 : (value.count / max) * 100}%`, transform: 'scaleY(1)' }} title={`${value.count} knowledge sources`}/></div><small>{value.label}</small></div>)}
      </div></div>
    </div>
  );
}

function ProgressRing({ projects }) {
  const linked = projects.filter((project) => Boolean(read(project, 'jiraProjectId', 'JiraProjectId'))).length;
  const total = projects.length;
  const progress = total ? Math.round((linked / total) * 100) : 0;
  const circumference = 2 * Math.PI * 54;
  return <div className="st-progress-overview"><div className="st-progress-ring" role="img" aria-label={`${progress}% of accessible projects have a Jira project linked`}><svg viewBox="0 0 128 128" aria-hidden="true"><circle className="st-progress-ring__track" cx="64" cy="64" r="54"/><circle className="st-progress-ring__value" cx="64" cy="64" r="54" style={{ strokeDasharray: circumference, '--ring-offset': circumference * (1 - progress / 100), strokeDashoffset: circumference * (1 - progress / 100) }}/></svg><div className="st-progress-ring__inner"><strong>{progress}<small>%</small></strong><span>Jira linked</span></div></div><span className="st-ring-caption"><i/> API project mapping</span><div className="st-progress-counts"><div><strong>{linked}</strong><small>Linked</small></div><div><strong>{total}</strong><small>Projects</small></div></div></div>;
}

function EmptyPanel({ icon = 'info', title, detail }) {
  return <div className="st-api-empty"><span><Icon name={icon} size={19}/></span><strong>{title}</strong><p>{detail}</p></div>;
}

export default function WorkspacePlaceholder() {
  const { user, logout } = useAuth();
  const [activeView, setActiveView] = useState('overview');
  const [activeNav, setActiveNav] = useState('overview');
  const [query, setQuery] = useState('');
  const [graphQuery, setGraphQuery] = useState('');
  const [graphCategory, setGraphCategory] = useState('All');
  const [selectedNodeId, setSelectedNodeId] = useState('');
  const [graphZoom, setGraphZoom] = useState(1);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [createMode, setCreateMode] = useState('');
  const [creating, setCreating] = useState(false);
  const [jiraSyncing, setJiraSyncing] = useState(false);
  const [jiraPending, setJiraPending] = useState(null);
  const [githubPending, setGithubPending] = useState(null);
  const [githubMapOpen, setGithubMapOpen] = useState(false);
  const [githubRepositories, setGithubRepositories] = useState([]);
  const [githubProjectId, setGithubProjectId] = useState('');
  const [githubRepositoryId, setGithubRepositoryId] = useState('');
  const [githubProjectStatus, setGithubProjectStatus] = useState(null);
  const [githubBusy, setGithubBusy] = useState(false);
  const [githubLoading, setGithubLoading] = useState(false);
  const [meetingDetail, setMeetingDetail] = useState(null);
  const [meetingDetailLoading, setMeetingDetailLoading] = useState(false);
  const [meetingDetailError, setMeetingDetailError] = useState('');
  const [meetingRetrying, setMeetingRetrying] = useState(false);
  const [meetingReviewing, setMeetingReviewing] = useState(false);
  const [meetingEvidenceDecisions, setMeetingEvidenceDecisions] = useState({});
  const [toast, setToast] = useState('');
  const [snapshot, setSnapshot] = useState({ projects: [], clients: [], employees: [], knowledgeSources: [], jiraStatus: { connected: null }, githubStatus: { connected: null }, resourceStates: {}, resourceErrors: {}, failures: [] });
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const searchRef = useRef(null);
  const graphSearchRef = useRef(null);
  const workspaceScrollRef = useRef(null);

  const projects = snapshot.projects;
  const clients = snapshot.clients;
  const employees = snapshot.employees;
  const knowledgeSources = snapshot.knowledgeSources;
  const jiraStatus = snapshot.jiraStatus;
  const githubStatus = snapshot.githubStatus || { connected: null };
  const resourceStates = snapshot.resourceStates || {};
  const resourceErrors = snapshot.resourceErrors || {};
  const projectById = useMemo(() => new Map(projects.map((project) => [projectIdOf(project), project])), [projects]);
  const clientById = useMemo(() => new Map(clients.map((client) => [clientIdOf(client), client])), [clients]);
  const graph = useMemo(() => buildGraphData(projects, clients, knowledgeSources), [projects, clients, knowledgeSources]);
  const meetingNotes = useMemo(() => knowledgeSources.filter((source) => sourceKind(source).replace(/[_\s-]/g, '').toLowerCase() === 'meetingnotes'), [knowledgeSources]);
  const projectSourceCounts = useMemo(() => {
    const map = new Map();
    knowledgeSources.forEach((source) => {
      const id = String(read(source, 'projectId', 'ProjectId') || '');
      if (id) map.set(id, (map.get(id) || 0) + 1);
    });
    return map;
  }, [knowledgeSources]);
  const filteredProjects = useMemo(() => {
    const term = query.trim().toLowerCase();
    return projects.filter((project) => {
      const client = clientById.get(String(read(project, 'clientId', 'ClientId') || ''));
      return !term || [projectLabel(project), projectIdOf(project), read(project, 'description', 'Description'), client && clientLabel(client)].some((part) => String(part || '').toLowerCase().includes(term));
    });
  }, [projects, query, clientById]);
  const displayName = user?.name || user?.email?.split('@')[0] || 'Workspace member';
  const initials = initialsFor(user);
  const roleNames = user?.roles || (user?.role ? [user.role] : []);
  const isAdmin = roleNames.some((role) => String(role).toLowerCase() === 'admin');
  const canReviewMeetingNotes = isAdmin || roleNames.some((role) => ['po', 'pm', 'productowner', 'projectmanager', 'product owner', 'project manager'].includes(String(role).toLowerCase().replace(/[_-]/g, ' ')));

  const reloadWorkspace = async () => {
    setLoading(true);
    setLoadError('');
    try {
      const next = await getWorkspaceSnapshot();
      setSnapshot(next);
      if (next.failures.length) setLoadError(next.failures.join(' · '));
    } catch (error) {
      setLoadError(error?.message || 'Could not load workspace data.');
    } finally { setLoading(false); }
  };

  useEffect(() => { reloadWorkspace(); }, []);

  useEffect(() => {
    const onKeyDown = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        if (activeView === 'graph') graphSearchRef.current?.focus();
        else searchRef.current?.focus();
      }
      if (event.key === 'Escape') { setNotificationsOpen(false); setProfileOpen(false); setCreateOpen(false); }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [activeView]);

  useEffect(() => {
    if (activeView !== 'overview') return undefined;
    const root = workspaceScrollRef.current;
    if (!root) return undefined;
    const targets = [...root.querySelectorAll('[data-st-reveal]')];
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (reduced || !('IntersectionObserver' in window)) { targets.forEach((item) => item.classList.add('is-visible')); return undefined; }
    const observer = new IntersectionObserver((entries) => entries.forEach((entry) => { if (entry.isIntersecting) { entry.target.classList.add('is-visible'); observer.unobserve(entry.target); } }), { threshold: .12, rootMargin: '0px 0px -24px 0px' });
    targets.forEach((item) => observer.observe(item));
    return () => observer.disconnect();
  }, [activeView, loading, projects.length, knowledgeSources.length]);

  useEffect(() => {
    if (graph.nodes.length && !graph.nodes.some((node) => node.id === selectedNodeId)) setSelectedNodeId(graph.nodes[0].id);
  }, [graph, selectedNodeId]);

  const jumpTo = (id, nav) => {
    setActiveView('overview');
    if (nav) setActiveNav(nav);
    window.requestAnimationFrame(() => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'center' }));
  };
  const handleSignOut = async () => { try { await logout(); } catch { /* Local credentials are cleared even when the API cannot confirm revocation. */ } finally { navigate('/login', { replace: true }); } };
  const navItems = [
    { id: 'overview', icon: 'grid', label: 'Overview' },
    { id: 'assistant', icon: 'chat', label: 'AI Assistant' },
    { id: 'graph', icon: 'graph', label: 'Knowledge Graph' },
    { id: 'projects', icon: 'folder', label: 'Projects', target: 'project-portfolio' },
    { id: 'meetings', icon: 'calendar', label: 'Meeting AI' },
    { id: 'integrations', icon: 'plug', label: 'Integrations' },
  ];
  const openNav = (item) => {
    setActiveNav(item.id); setProfileOpen(false); setNotificationsOpen(false); setCreateOpen(false);
    if (item.id === 'assistant' || item.id === 'graph' || item.id === 'integrations' || item.id === 'meetings') { setActiveView(item.id); setGraphZoom(1); return; }
    setActiveView('overview');
    if (item.target) jumpTo(item.target, item.id);
    else if (item.id === 'overview') workspaceScrollRef.current?.scrollTo({ top: 0, behavior: 'smooth' });
  };
  const handleJiraConnect = async () => {
    try {
      const response = await connectJira();
      const url = typeof response === 'string' ? response : response?.url || response?.authorizationUrl;
      if (typeof url !== 'string' || !url.startsWith('https://')) throw new Error('The backend did not return a valid Jira authorization URL.');
      window.location.assign(url);
    } catch (error) { setToast(error?.data?.detail || error?.data?.message || error.message || 'Jira connection could not start.'); }
  };

  const handleJiraSync = async () => {
    setJiraSyncing(true);
    try {
      await startJiraSync();
      setToast('Jira sync has been queued by the backend.');
      await reloadWorkspace();
    } catch (error) { setToast(error?.data?.detail || error?.data?.message || error.message || 'Jira sync could not be started.'); }
    finally { setJiraSyncing(false); }
  };

  const handleGitHubConnect = async () => {
    setGithubBusy(true);
    try {
      const response = await connectGitHub();
      const url = response?.url || response?.authorizationUrl;
      if (typeof url !== 'string' || !url.startsWith('https://github.com/')) throw new Error('The backend did not return a valid GitHub authorization URL.');
      window.location.assign(url);
    } catch (error) { setToast(error?.data?.message || error?.message || 'GitHub connection could not start.'); }
    finally { setGithubBusy(false); }
  };

  const openGitHubMapping = async () => {
    setGithubMapOpen(true);
    setGithubLoading(true);
    setGithubProjectStatus(null);
    try {
      const repos = await getGitHubRepositories();
      setGithubRepositories(repos);
      const initialProject = githubProjectId || projects[0]?.projectId || projects[0]?.ProjectId || projects[0]?.id || projects[0]?.Id || '';
      setGithubProjectId(String(initialProject));
      if (initialProject) {
        const status = await getGitHubProjectStatus(String(initialProject));
        setGithubProjectStatus(status);
        setGithubRepositoryId(status?.repositoryId ? String(status.repositoryId) : '');
      }
    } catch (error) {
      setGithubRepositories([]);
      setToast(error?.data?.message || error?.message || 'GitHub repositories could not be loaded.');
    } finally { setGithubLoading(false); }
  };

  const handleGitHubProjectChange = async (projectId) => {
    setGithubProjectId(projectId);
    setGithubProjectStatus(null);
    setGithubRepositoryId('');
    if (!projectId) return;
    setGithubLoading(true);
    try {
      const status = await getGitHubProjectStatus(projectId);
      setGithubProjectStatus(status);
      setGithubRepositoryId(status?.repositoryId ? String(status.repositoryId) : '');
    } catch (error) { setToast(error?.data?.message || error?.message || 'Project GitHub status could not be loaded.'); }
    finally { setGithubLoading(false); }
  };

  const handleGitHubMap = async () => {
    if (!githubProjectId || !githubRepositoryId) return;
    setGithubBusy(true);
    try {
      await mapGitHubRepository(githubProjectId, Number(githubRepositoryId));
      setToast('GitHub repository mapped to the project. Use Sync now to request the first index.');
      setGithubProjectStatus(await getGitHubProjectStatus(githubProjectId));
      await reloadWorkspace();
    } catch (error) { setToast(error?.data?.message || error?.message || 'GitHub repository could not be mapped.'); }
    finally { setGithubBusy(false); }
  };

  const handleGitHubSync = async () => {
    if (!githubProjectId) return;
    setGithubBusy(true);
    try {
      await syncGitHubProject(githubProjectId);
      setToast('GitHub project synchronization has been queued.');
      setGithubProjectStatus(await getGitHubProjectStatus(githubProjectId));
    } catch (error) { setToast(error?.data?.message || error?.message || 'GitHub synchronization could not be started.'); }
    finally { setGithubBusy(false); }
  };

  const handleGitHubUnmap = async () => {
    if (!githubProjectId) return;
    setGithubBusy(true);
    try {
      await unmapGitHubRepository(githubProjectId);
      setGithubRepositoryId('');
      setGithubProjectStatus(await getGitHubProjectStatus(githubProjectId));
      setToast('GitHub repository unlinked from the project.');
      await reloadWorkspace();
    } catch (error) { setToast(error?.data?.message || error?.message || 'GitHub repository could not be unlinked.'); }
    finally { setGithubBusy(false); }
  };

  const handleGitHubComplete = async () => {
    if (!githubPending?.completionId || !githubPending?.selectedInstallationId) return;
    setGithubPending((current) => ({ ...current, submitting: true, error: '' }));
    try {
      await completeGitHubConnection({ completionId: githubPending.completionId, installationId: Number(githubPending.selectedInstallationId) });
      setGithubPending(null);
      setToast('GitHub App connected successfully. You can now map repositories to projects.');
      await reloadWorkspace();
    } catch (error) {
      setGithubPending((current) => current ? { ...current, submitting: false, error: error?.data?.message || error?.message || 'GitHub installation could not be completed.' } : current);
    }
  };

  const handleOpenMeetingNote = async (note) => {
    const id = sourceIdOf(note);
    if (!id) return;
    setMeetingDetail({ source: note, sourceText: '', evidence: [] });
    setMeetingDetailError('');
    setMeetingDetailLoading(true);
    try {
      const detail = await getKnowledgeSource(id, read(note, 'version', 'Version'));
      setMeetingDetail(detail);
      const evidence = detail?.evidence || detail?.Evidence || [];
      setMeetingEvidenceDecisions(Object.fromEntries(evidence.map((item) => [item.id || item.Id, String(item.decision || item.Decision).toLowerCase() === 'approved'])));
    } catch (error) { setMeetingDetailError(error?.data?.detail || error?.data?.message || error?.message || 'Meeting note could not be loaded.'); }
    finally { setMeetingDetailLoading(false); }
  };

  const handleRetryMeetingNote = async () => {
    const source = meetingDetail?.source || meetingDetail?.Source || meetingDetail;
    const id = read(source, 'id', 'Id');
    const version = read(source, 'version', 'Version');
    if (!id || !version) return;
    setMeetingRetrying(true);
    try {
      await retryKnowledgeExtraction(id, version);
      setToast('AI extraction retry has been queued for this meeting note.');
      const detail = await getKnowledgeSource(id, version);
      setMeetingDetail(detail);
      await reloadWorkspace();
    } catch (error) { setMeetingDetailError(error?.data?.detail || error?.data?.message || error?.message || 'AI extraction could not be retried.'); }
    finally { setMeetingRetrying(false); }
  };

  const handleReviewMeetingNote = async () => {
    const source = meetingDetail?.source || meetingDetail?.Source || meetingDetail;
    const id = read(source, 'id', 'Id');
    const version = read(source, 'version', 'Version');
    const evidence = meetingDetail?.evidence || meetingDetail?.Evidence || [];
    if (!id || !version || !evidence.length) return;
    const decisions = evidence.map((item) => ({ id: item.id || item.Id, approve: Boolean(meetingEvidenceDecisions[item.id || item.Id]) }));
    if (!decisions.some((item) => item.approve)) {
      setMeetingDetailError('Approve at least one extracted item before publishing.');
      return;
    }
    setMeetingReviewing(true);
    setMeetingDetailError('');
    try {
      await reviewKnowledgeSource(id, version, decisions, true);
      const detail = await getKnowledgeSource(id, version);
      setMeetingDetail(detail);
      setToast('Meeting evidence reviewed and published to the project knowledge base.');
      await reloadWorkspace();
    } catch (error) { setMeetingDetailError(error?.data?.detail || error?.data?.message || error?.message || 'Meeting review could not be saved.'); }
    finally { setMeetingReviewing(false); }
  };

  const handleCreateResource = async (values) => {
    setCreating(true);
    try {
      if (createMode === 'client') {
        await createClient({ clientName: values.clientName.trim(), email: values.email.trim() || null, phoneNumber: values.phoneNumber.trim() || null });
        setToast('Client created successfully.');
      } else if (createMode === 'project') {
        await createProject({ clientId: values.clientId, name: values.name.trim(), description: values.description.trim() || null });
        setToast('Project created successfully.');
      } else if (createMode === 'meeting') {
        await createMeetingNote({
          clientId: values.clientId, projectId: values.projectId, kind: 'MeetingNotes', title: values.title.trim(),
          text: values.text.trim(), meetingMode: values.meetingMode, meetingAt: new Date(values.meetingAt).toISOString(),
        });
        setToast('Meeting note saved. Knowledge extraction is now handled by the backend workflow.');
      }
      setCreateMode(''); setCreateOpen(false);
      await reloadWorkspace();
    } finally { setCreating(false); }
  };

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const status = params.get('status');
    const pendingId = params.get('pendingId');
    if (status === 'success') {
      setToast('Jira authorization completed. Refreshing the company connection status…');
      reloadWorkspace();
      window.history.replaceState({}, '', window.location.pathname);
    } else if (status === 'select-site' && pendingId) {
      setJiraPending({ pendingId, sites: [], selectedCloudId: '', loading: true, error: '' });
      getPendingJiraSites(pendingId).then((sites) => {
        const list = Array.isArray(sites) ? sites : [];
        setJiraPending((current) => current ? { ...current, sites: list, selectedCloudId: list[0]?.cloudId || list[0]?.CloudId || '', loading: false } : current);
      }).catch((error) => setJiraPending((current) => current ? { ...current, loading: false, error: error?.data?.detail || error?.data?.message || error.message } : current));
      window.history.replaceState({}, '', window.location.pathname);
    } else if (status === 'confirm' && params.get('completionId')) {
      const completionId = params.get('completionId');
      setGithubPending({ completionId, kind: '', githubLogin: '', installations: [], selectedInstallationId: '', loading: true, submitting: false, error: '' });
      getGitHubPending(completionId).then((pending) => {
        const installations = Array.isArray(pending?.installations) ? pending.installations : [];
        setGithubPending((current) => current ? { ...current, kind: pending?.kind || '', githubLogin: pending?.githubLogin || '', installations, selectedInstallationId: installations.length === 1 ? String(installations[0].installationId) : '', loading: false } : current);
      }).catch((error) => setGithubPending((current) => current ? { ...current, loading: false, error: error?.data?.message || error?.message || 'GitHub confirmation could not be loaded.' } : current));
      window.history.replaceState({}, '', window.location.pathname);
    } else if (status === 'awaiting-approval') {
      setToast('GitHub installation is waiting for an organization owner approval.');
      window.history.replaceState({}, '', window.location.pathname);
    } else if (status === 'no-eligible-installations') {
      setToast('No eligible GitHub App installation was found for this account. Install the SynTrace GitHub App and try again.');
      window.history.replaceState({}, '', window.location.pathname);
    }
  }, []);

  const finishJiraSiteSelection = async () => {
    if (!jiraPending?.pendingId || !jiraPending.selectedCloudId) return;
    setJiraPending((current) => ({ ...current, submitting: true, error: '' }));
    try {
      await completeJiraConnection(jiraPending.pendingId, jiraPending.selectedCloudId);
      setJiraPending(null); setToast('Jira site connected successfully.'); await reloadWorkspace();
    } catch (error) { setJiraPending((current) => current ? { ...current, submitting: false, error: error?.data?.detail || error?.data?.message || error.message } : current); }
  };

  const jiraConnectionLabel = jiraStatus.connected === true ? 'Connected' : jiraStatus.connected === false ? 'Not connected' : (jiraStatus.error?.includes('restricted') ? 'Restricted' : 'Unavailable');
  const jiraSite = jiraStatus.site || jiraStatus.siteUrl || jiraStatus.jiraSiteUrl;
  const jiraLastSync = jiraStatus.lastSyncedAt ? `Last sync ${formatDate(jiraStatus.lastSyncedAt)}` : 'No successful sync timestamp returned';
  const githubConnectionLabel = githubStatus.suspended ? 'Suspended' : githubStatus.connected === true ? 'Connected' : githubStatus.connected === false ? 'Not connected' : (githubStatus.error?.includes('restricted') ? 'Restricted' : 'Unavailable');

  return (
    <main className="st-stage">
      <div className="st-frame">
        {toast && <div className="st-toast" role="status"><Icon name="info" size={15}/><span>{toast}</span><button type="button" aria-label="Dismiss notification" onClick={() => setToast('')}><Icon name="close" size={14}/></button></div>}
        {createMode && <WorkspaceCreateDialog mode={createMode} clients={clients} projects={projects} busy={creating} onClose={() => !creating && setCreateMode('')} onSubmit={handleCreateResource}/>}
        {jiraPending && <div className="st-dialog-backdrop" role="presentation"><section className="st-dialog st-jira-site-dialog" role="dialog" aria-modal="true" aria-labelledby="st-jira-site-title"><header className="st-dialog__header"><div><span className="st-section-label">ATLASSIAN AUTHORIZATION</span><h2 id="st-jira-site-title">Choose your Jira site</h2><p>Select the company Jira Cloud site to finish linking this workspace.</p></div><button type="button" className="st-dialog__close" onClick={() => setJiraPending(null)} aria-label="Close">×</button></header><div className="st-dialog__form">{jiraPending.loading ? <div className="st-chat-loading">Loading available Jira sites…</div> : jiraPending.sites.length ? <label>Jira Cloud site<select value={jiraPending.selectedCloudId} onChange={(event) => setJiraPending((current) => ({ ...current, selectedCloudId: event.target.value }))}>{jiraPending.sites.map((site) => <option key={site.cloudId || site.CloudId} value={site.cloudId || site.CloudId}>{site.siteUrl || site.SiteUrl}</option>)}</select></label> : <p className="st-dialog__hint">No Jira sites were returned for this authorization.</p>}{jiraPending.error && <div className="st-dialog__error" role="alert">{jiraPending.error}</div>}<footer className="st-dialog__footer"><button type="button" className="st-dialog__cancel" onClick={() => setJiraPending(null)}>Cancel</button><button type="button" className="st-dialog__submit" disabled={jiraPending.loading || jiraPending.submitting || !jiraPending.selectedCloudId} onClick={finishJiraSiteSelection}>{jiraPending.submitting ? 'Connecting…' : 'Connect site'}</button></footer></div></section></div>}
        {githubPending && <div className="st-dialog-backdrop" role="presentation"><section className="st-dialog" role="dialog" aria-modal="true" aria-labelledby="st-github-confirm-title"><header className="st-dialog__header"><div><span className="st-section-label">GITHUB APP AUTHORIZATION</span><h2 id="st-github-confirm-title">Choose GitHub installation</h2><p>Confirm the organization or account that SynTrace may access{githubPending.githubLogin ? ` · ${githubPending.githubLogin}` : ''}.</p></div><button type="button" className="st-dialog__close" onClick={() => setGithubPending(null)} aria-label="Close">×</button></header><div className="st-dialog__form">{githubPending.loading ? <div className="st-chat-loading">Loading verified GitHub installations…</div> : githubPending.installations.length ? <label>GitHub installation<select value={githubPending.selectedInstallationId} onChange={(event) => setGithubPending((current) => ({ ...current, selectedInstallationId: event.target.value }))}><option value="">Choose an installation</option>{githubPending.installations.map((item) => <option key={item.installationId} value={item.installationId}>{item.accountLogin} · {item.accountType}{item.repositoryCount != null ? ` · ${item.repositoryCount} repositories` : ''}</option>)}</select></label> : <p className="st-dialog__hint">No eligible installation was returned. Install the SynTrace GitHub App for the organization, then restart the connection.</p>}{githubPending.error && <div className="st-dialog__error" role="alert">{githubPending.error}</div>}<footer className="st-dialog__footer"><button type="button" className="st-dialog__cancel" onClick={() => setGithubPending(null)}>Cancel</button><button type="button" className="st-dialog__submit" disabled={githubPending.loading || githubPending.submitting || !githubPending.selectedInstallationId} onClick={handleGitHubComplete}>{githubPending.submitting ? 'Connecting…' : 'Confirm installation'}</button></footer></div></section></div>}
        {githubMapOpen && <div className="st-dialog-backdrop" role="presentation"><section className="st-dialog" role="dialog" aria-modal="true" aria-labelledby="st-github-map-title"><header className="st-dialog__header"><div><span className="st-section-label">PROJECT REPOSITORY</span><h2 id="st-github-map-title">Map a GitHub repository</h2><p>Connect one repository to a project. SynTrace will index commits, pull requests and permitted code context.</p></div><button type="button" className="st-dialog__close" onClick={() => setGithubMapOpen(false)} aria-label="Close">×</button></header><div className="st-dialog__form">{!projects.length ? <p className="st-dialog__hint">Create a project before mapping a repository.</p> : <><label>Project<select value={githubProjectId} onChange={(event) => handleGitHubProjectChange(event.target.value)}>{projects.map((project) => { const id = projectIdOf(project); return <option key={id} value={id}>{projectLabel(project)}</option>; })}</select></label><label>GitHub repository<select value={githubRepositoryId} onChange={(event) => setGithubRepositoryId(event.target.value)} disabled={githubLoading || !githubRepositories.length}><option value="">Choose a repository</option>{githubRepositories.map((repo) => <option key={repo.repositoryId} value={repo.repositoryId}>{repo.fullName}{repo.isPrivate ? ' · Private' : ''}</option>)}</select></label>{githubLoading && <div className="st-chat-loading">Loading repository access…</div>}{githubProjectStatus?.fullName && <p className="st-dialog__hint">Current mapping: {githubProjectStatus.fullName} · Sync: {statusText(githubProjectStatus.syncStatus)}. Unlink it before choosing a different repository.</p>}{!githubLoading && !githubRepositories.length && <p className="st-dialog__hint">No repositories were returned. Check the GitHub App installation and repository permissions.</p>}</> }<footer className="st-dialog__footer"><button type="button" className="st-dialog__cancel" onClick={() => setGithubMapOpen(false)}>Close</button>{githubProjectStatus?.repositoryId && <button type="button" className="st-dialog__cancel" disabled={githubBusy || githubLoading} onClick={handleGitHubUnmap}>Unlink</button>}{githubProjectStatus?.repositoryId && <button type="button" className="st-dialog__cancel" disabled={githubBusy || githubLoading} onClick={handleGitHubSync}>Sync now</button>}<button type="button" className="st-dialog__submit" disabled={githubBusy || githubLoading || !githubProjectId || !githubRepositoryId || !projects.length || (githubProjectStatus?.repositoryId && String(githubProjectStatus.repositoryId) !== githubRepositoryId)} onClick={handleGitHubMap}>{githubBusy ? 'Working…' : githubProjectStatus?.repositoryId ? 'Repository mapped' : 'Map repository'}</button></footer></div></section></div>}
        {meetingDetail && <div className="st-dialog-backdrop" role="presentation"><section className="st-dialog st-meeting-detail-dialog" role="dialog" aria-modal="true" aria-labelledby="st-meeting-detail-title"><header className="st-dialog__header"><div><span className="st-section-label">MEETING KNOWLEDGE</span><h2 id="st-meeting-detail-title">{read(meetingDetail.source || meetingDetail.Source || meetingDetail, 'title', 'Title') || 'Meeting note'}</h2><p>Original meeting content and AI-extracted evidence returned by SynTrace.</p></div><button type="button" className="st-dialog__close" onClick={() => setMeetingDetail(null)} aria-label="Close">×</button></header><div className="st-dialog__form">{meetingDetailLoading ? <div className="st-chat-loading">Loading meeting note…</div> : meetingDetailError ? <div className="st-dialog__error" role="alert">{meetingDetailError}</div> : <><div className="st-meeting-detail-meta"><span>Status: {statusText(read(meetingDetail.source || meetingDetail.Source || meetingDetail, 'status', 'Status'))}</span><span>Version: {read(meetingDetail.source || meetingDetail.Source || meetingDetail, 'version', 'Version') ?? '—'}</span>{meetingDetail.failureCode || meetingDetail.FailureCode ? <span>Failure: {meetingDetail.failureCode || meetingDetail.FailureCode}</span> : null}</div><label>Original content<textarea readOnly rows="7" value={meetingDetail.sourceText || meetingDetail.SourceText || ''}/></label><div className="st-meeting-evidence-list"><strong>AI extracted evidence ({(meetingDetail.evidence || meetingDetail.Evidence || []).length})</strong>{(meetingDetail.evidence || meetingDetail.Evidence || []).map((item) => { const evidenceId = item.id || item.Id; return <article key={evidenceId}><span>{statusText(item.kind || item.Kind)} · {statusText(item.decision || item.Decision)}</span><p>{item.text || item.Text}</p><small>“{item.quote || item.Quote}”</small>{canReviewMeetingNotes && String(read(meetingDetail.source || meetingDetail.Source || meetingDetail, 'status', 'Status')).toLowerCase() === 'awaitingreview' && <label className="st-meeting-evidence-approval"><input type="checkbox" checked={Boolean(meetingEvidenceDecisions[evidenceId])} onChange={(event) => setMeetingEvidenceDecisions((current) => ({ ...current, [evidenceId]: event.target.checked }))}/> Approve this item for publication</label>}</article>; })}{!(meetingDetail.evidence || meetingDetail.Evidence || []).length && <p className="st-dialog__hint">No extracted evidence is available yet. If processing is pending, refresh this note in a moment.</p>}</div></>}{(() => { const source = meetingDetail.source || meetingDetail.Source || meetingDetail; const state = String(read(source, 'status', 'Status') || '').toLowerCase(); const canRetry = state === 'extractionfailed'; return <footer className="st-dialog__footer"><button type="button" className="st-dialog__cancel" onClick={() => setMeetingDetail(null)}>Close</button>{canReviewMeetingNotes && String(read(source, 'status', 'Status')).toLowerCase() === 'awaitingreview' && (meetingDetail.evidence || meetingDetail.Evidence || []).length > 0 && <button type="button" className="st-dialog__submit" disabled={meetingReviewing || meetingDetailLoading} onClick={handleReviewMeetingNote}>{meetingReviewing ? 'Publishing…' : 'Publish approved evidence'}</button>}{canRetry && <button type="button" className="st-dialog__submit" disabled={meetingRetrying || meetingDetailLoading} onClick={handleRetryMeetingNote}>{meetingRetrying ? 'Retrying…' : 'Retry AI extraction'}</button>}</footer>; })()}</div></section></div>}
        <header className="st-topbar">
          <div className="st-topbar__brand-area">
            <a className="st-brand" href="#workspace" onClick={(event) => { event.preventDefault(); openNav({ id: 'overview' }); workspaceScrollRef.current?.scrollTo({ top: 0, behavior: 'smooth' }); }} aria-label="SynTrace home"><img src={assetUrl('assets/syntrace-mark.webp')} alt="SynTrace"/></a>
            <div className="st-workspace-switcher"><span className="st-workspace-symbol">S</span><span><strong>SynTrace</strong><small>{loading ? 'Loading workspace…' : 'Company workspace'}</small></span><Icon name="chevron" size={14}/></div>
            <button type="button" className={`st-ai-launch ${activeView === 'assistant' ? 'is-open' : ''}`} onClick={() => openNav({ id: 'assistant' })}><span className="st-ai-launch__icon"><Icon name="spark" size={15}/></span><span>AI Assistant</span></button><button type="button" className={`st-integrations-launch ${activeView === 'integrations' ? 'is-open' : ''}`} onClick={() => openNav({ id: 'integrations' })}><Icon name="plug" size={15}/><span>Integrations</span></button>
          </div>
          <label className="st-search"><Icon name="search" size={17}/><input ref={searchRef} value={query} onChange={(event) => setQuery(event.target.value)} onFocus={() => { if (activeView !== 'overview') openNav({ id: 'overview' }); }} placeholder="Search accessible projects…" aria-label="Search accessible projects"/><kbd>⌘ K</kbd></label>
          <div className="st-topbar__tools">
            <div className="st-dropdown-anchor"><button type="button" className={`st-round-button ${notificationsOpen ? 'is-active' : ''}`} aria-label="Notifications" aria-expanded={notificationsOpen} onClick={() => { setNotificationsOpen((open) => !open); setProfileOpen(false); }}><Icon name="bell" size={17}/></button>
              {notificationsOpen && <div className="st-popover st-notification-popover"><div className="st-popover__head"><strong>Notifications</strong><span>Workspace</span></div><EmptyPanel icon="bell" title="No notification feed" detail="A notifications endpoint is not exposed by the current backend API."/></div>}
            </div>
            <ThemeToggle className="st-theme-toggle"/>
            <div className="st-dropdown-anchor"><button type="button" className="st-profile-button" onClick={() => { setProfileOpen((open) => !open); setNotificationsOpen(false); }} aria-label="Open profile menu" aria-expanded={profileOpen}><span>{initials}</span></button>
              {profileOpen && <div className="st-popover st-profile-popover"><strong>{displayName}</strong><small>{user?.email}</small><span className="st-profile-role">{roleNames.join(', ') || 'Workspace member'}</span><button type="button" onClick={handleSignOut}><Icon name="logout" size={15}/>Sign out</button></div>}
            </div>
          </div>
        </header>

        <div className="st-frame__body">
          <aside className="st-rail" aria-label="Workspace navigation"><div className="st-rail__primary">{navItems.map((item) => <button key={item.id} type="button" title={item.label} aria-label={item.label} aria-pressed={activeNav === item.id} className={`st-rail__item ${activeNav === item.id ? 'is-active' : ''}`} onClick={() => openNav(item)}><Icon name={item.icon} size={19}/></button>)}</div><div className="st-rail__bottom"><button type="button" className="st-rail__item" title="Reload workspace data" aria-label="Reload workspace data" onClick={reloadWorkspace}><Icon name="refresh" size={19}/></button></div></aside>

          <section className="st-workspace" aria-label="SynTrace workspace">
            <div className="st-workspace__scroll" ref={workspaceScrollRef} key={activeView}>
              {activeView === 'assistant' ? <ChatPage currentUser={user}/> : activeView === 'meetings' ? <MeetingAI projects={projects} onBack={() => openNav({ id: 'overview' })}/> : activeView === 'integrations' ? (
                <IntegrationHub
                  githubStatus={githubStatus}
                  jiraStatus={jiraStatus}
                  githubBusy={githubBusy}
                  jiraBusy={jiraSyncing}
                  isAdmin={isAdmin}
                  meetingCount={meetingNotes.length}
                  onConnectGitHub={handleGitHubConnect}
                  onManageGitHub={openGitHubMapping}
                  onConnectJira={handleJiraConnect}
                  onSyncJira={handleJiraSync}
                  onCreateMeeting={() => openNav({ id: 'meetings' })}
                  onViewMeetings={() => openNav({ id: 'meetings' })}
                  onSlackConnect={() => setToast('Slack connection requires backend OAuth, secure token storage, callback and event/webhook endpoints. No Slack integration API is currently available.')}
                />
              ) : activeView === 'graph' ? (
                <WorkspaceGraph nodes={graph.nodes} edges={graph.edges} query={graphQuery} setQuery={setGraphQuery} searchRef={graphSearchRef} selectedId={selectedNodeId} setSelectedId={setSelectedNodeId} category={graphCategory} setCategory={setGraphCategory} zoom={graphZoom} setZoom={setGraphZoom}/>
              ) : (
                <div className="st-overview-view st-view-enter">
                  <section className="st-project-heading">
                    <div className="st-project-heading__left"><div className="st-breadcrumb"><span>Workspace</span><b>/</b><strong>Overview</strong></div><div className="st-title-line"><div><span className="st-eyebrow">PROJECT INTELLIGENCE</span><h1>Workspace overview</h1></div><span className="st-demo-tag"><i/>{loading ? 'SYNCING WORKSPACE' : snapshot.failures.length ? 'PARTIAL API DATA' : 'API SNAPSHOT'}</span></div><p className="st-heading-copy">A connected view of your accessible projects, clients and project knowledge.</p></div>
                    <div className="st-project-actions"><button type="button" className="st-text-action" onClick={() => openNav({ id: 'graph' })}><Icon name="graph" size={16}/> Explore context</button><div className="st-avatars" aria-label={`${employees.length} workspace members`}><span>{employees.length}</span><b>Members</b></div><div className="st-dropdown-anchor"><button type="button" className="st-new-button" onClick={() => setCreateOpen((open) => !open)} aria-expanded={createOpen}><Icon name="plus" size={15}/> New <Icon name="chevron" size={14}/></button>{createOpen && <div className="st-popover st-create-popover"><strong>Create in SynTrace</strong><button type="button" onClick={() => { setCreateOpen(false); openNav({ id: 'assistant' }); }}><Icon name="spark" size={15}/> Ask the assistant <small>Available</small></button><button type="button" disabled={!isAdmin || creating} onClick={() => { setCreateOpen(false); setCreateMode('project'); }}><Icon name="folder" size={15}/> New project <small>{isAdmin ? 'Admin' : 'Restricted'}</small></button><button type="button" disabled={!isAdmin || creating} onClick={() => { setCreateOpen(false); setCreateMode('client'); }}><Icon name="users" size={15}/> New client <small>{isAdmin ? 'Admin' : 'Restricted'}</small></button><button type="button" disabled={creating || !projects.length} onClick={() => { setCreateOpen(false); openNav({ id: 'meetings' }); }}><Icon name="book" size={15}/> New meeting analysis <small>{projects.length ? 'Available' : 'No projects'}</small></button></div>}</div></div>
                  </section>

                  {loadError && <div className="st-api-warning" role="status"><Icon name="info" size={15}/><span>{loadError}</span><button type="button" onClick={reloadWorkspace}>Retry</button></div>}

                  <div className="st-dashboard-grid">
                    <div className="st-dashboard-main">
                      <section className="st-insight-panel" id="project-performance" data-st-reveal>
                        <div className="st-insight-heading"><div><span className="st-section-label">DELIVERY OVERVIEW</span><h2>Workspace coverage</h2><p>Projects and knowledge records currently available to your account.</p></div><span className="st-period-label">CURRENT SNAPSHOT</span></div>
                        <div className="st-summary-inline"><div className="st-summary-stat"><small>Accessible projects</small><strong>{loading ? '—' : projects.length}</strong></div><div className="st-summary-stat"><small>Clients</small><strong>{loading ? '—' : clients.length}</strong></div><div className="st-summary-stat"><small>Team members</small><strong>{loading ? '—' : employees.length}</strong></div></div>
                        <div className="st-insight-content">
                          <div className="st-activity-chart"><div className="st-chart-title"><strong>Knowledge by project</strong><span>Knowledge source records by project · first 7 projects</span></div>{projects.length ? <BarChart projects={projects} sources={knowledgeSources}/> : <EmptyPanel icon="folder" title="No project data to chart" detail="Projects returned by the backend will appear here."/>}<div className="st-chart-legend"><span><i className="st-legend-dot st-legend-dot--blue"/> Knowledge sources</span></div></div>
                          <ProgressRing projects={projects}/>
                        </div>
                        <div className="st-activity-track"><div className="st-activity-track__line"><i/></div><span className="st-track-point st-track-point--start"/><span className="st-track-point st-track-point--middle"/><span className="st-track-point st-track-point--end"/><div className="st-track-label st-track-label--left"><small>PROJECTS</small><strong>{projects.length}</strong></div><div className="st-track-label st-track-label--middle"><small>JIRA MAPPED</small><strong>{projects.filter((project) => Boolean(read(project, 'jiraProjectId', 'JiraProjectId'))).length}</strong></div><div className="st-track-label st-track-label--right"><small>KNOWLEDGE SOURCES</small><strong>{knowledgeSources.length}</strong></div></div>
                        <div className="st-panel-footnote">Values are loaded from your authenticated, company-scoped APIs. No Jira issue totals or task completion percentages are inferred.</div>
                      </section>

                      <section className="st-calendar-panel" id="task-calendar" data-st-reveal>
                        <div className="st-calendar-toolbar"><div className="st-calendar-toolbar__title"><div><span className="st-section-label">DELIVERY WORK</span><h2>Tasks & milestones</h2></div><span className="st-period-label">JIRA ISSUES / SPRINTS</span></div><div className="st-calendar-toolbar__actions"><button type="button" className="st-calendar-tool" onClick={() => openNav({ id: 'assistant' })}><Icon name="spark" size={14}/> Investigate with AI</button></div></div>
                        <div className="st-calendar-content"><EmptyPanel icon="calendar" title="Task schedule is not available through the current API" detail="This backend branch does not expose a Jira issue list, sprint list, task due dates or a team calendar endpoint. Connect Jira and use the AI Assistant to investigate records that are in its accessible context."/></div>
                        <div className="st-calendar-foot"><span><i className="st-legend-dot st-legend-dot--blue"/> Jira integration</span><span><i className="st-legend-dot st-legend-dot--mint"/> AI investigation</span><small>Schedule appears when a supported task/calendar API is available</small></div>
                      </section>

                      <section className="st-project-portfolio" id="project-portfolio" data-st-reveal><div className="st-panel-title-row"><div><span className="st-section-label">PORTFOLIO</span><h2>Projects</h2></div><span className="st-data-note">{filteredProjects.length} accessible projects</span></div>
                        <div className="st-project-table"><div className="st-project-table__head"><span>PROJECT</span><span>JIRA MAPPING</span><span>KNOWLEDGE</span><span>ACCESS</span></div>
                          {filteredProjects.map((project, index) => { const id = projectIdOf(project); const clientId = String(read(project, 'clientId', 'ClientId') || ''); const client = clientById.get(clientId); const jiraId = read(project, 'jiraProjectId', 'JiraProjectId'); const count = projectSourceCounts.get(id) || 0; const tone = toneForIndex(index); return <button type="button" className="st-project-row" key={id} onClick={() => { setGraphQuery(projectLabel(project)); openNav({ id: 'graph' }); }}><span className="st-project-cell"><i className={`st-project-mark st-project-mark--${tone}`}>{projectLabel(project).slice(0, 1).toUpperCase()}</i><span><strong>{projectLabel(project)}</strong><small>{client ? clientLabel(client) : id}</small></span></span><span className="st-project-status">{jiraId ? `Linked · ${jiraId}` : 'Not linked'}</span><span className="st-project-issue-count">{count} sources</span><span className="st-project-status st-project-status--mint">Accessible</span></button>; })}
                          {!loading && !filteredProjects.length && <div className="st-project-empty">{projects.length ? 'No projects match your search.' : 'No accessible projects were returned for this account.'}</div>}
                          {loading && <div className="st-project-empty">Loading projects…</div>}
                        </div>
                      </section>
                    </div>

                    <aside className="st-right-column">
                      <section className="st-side-panel st-deadlines-panel" id="assistant-panel" data-st-reveal>
                        <div className="st-side-panel__heading"><span className="st-panel-icon"><Icon name="link" size={17}/></span><div><span className="st-section-label">INTEGRATION STATUS</span><h2>Jira connection</h2></div><span className="st-panel-count">{jiraStatus.connected === true ? '01' : '00'}</span></div>
                        <div className="st-jira-status-card"><div className="st-jira-status-card__top"><span className={`st-jira-indicator ${jiraStatus.connected === true ? 'is-connected' : ''}`}/><strong>{jiraConnectionLabel}</strong></div><p>{jiraSite || (jiraStatus.connected === true ? 'Jira Cloud site linked to this company' : jiraStatus.connected === false ? 'No company Jira connection was returned by the API.' : (jiraStatus.error || 'Jira status could not be loaded.'))}</p><small>{jiraLastSync}</small>{jiraStatus.lastSyncError && <div className="st-jira-error">{jiraStatus.lastSyncError}</div>}</div>
                        {isAdmin && jiraStatus.connected === false && <button type="button" className="st-activity-link" onClick={handleJiraConnect}>Connect Jira <Icon name="arrow" size={13}/></button>}
                        {isAdmin && jiraStatus.connected === true && <button type="button" className="st-activity-link" onClick={handleJiraSync} disabled={jiraSyncing}><Icon name="refresh" size={13}/>{jiraSyncing ? 'Queueing sync…' : 'Sync Jira now'}</button>}
                        <div className="st-side-footnote">Sync state is read from GET /api/integrations/jira/sync/status. Jira issue and sprint lists are not exposed by this API.</div>
                      </section>

                      <section className="st-side-panel st-deadlines-panel" id="github-panel" data-st-reveal>
                        <div className="st-side-panel__heading"><span className="st-panel-icon"><Icon name="link" size={17}/></span><div><span className="st-section-label">SOURCE CONTROL</span><h2>GitHub</h2></div><span className="st-panel-count">{githubStatus.connected === true && !githubStatus.suspended ? '01' : '00'}</span></div>
                        <div className="st-jira-status-card"><div className="st-jira-status-card__top"><span className={`st-jira-indicator ${githubStatus.connected === true && !githubStatus.suspended ? 'is-connected' : ''}`}/><strong>{githubConnectionLabel}</strong></div><p>{githubStatus.accountLogin || (githubStatus.connected === true ? 'GitHub App installation linked to this company' : githubStatus.connected === false ? 'No company GitHub App installation is connected.' : (githubStatus.error || 'GitHub status could not be loaded.'))}</p><small>Company-level GitHub App · repository access is selected per project</small></div>
                        {isAdmin && githubStatus.connected !== true && <button type="button" className="st-activity-link" onClick={handleGitHubConnect} disabled={githubBusy}><Icon name="link" size={13}/>{githubBusy ? 'Opening GitHub…' : 'Connect GitHub'}</button>}
                        {isAdmin && githubStatus.connected === true && !githubStatus.suspended && <button type="button" className="st-activity-link" onClick={openGitHubMapping}><Icon name="folder" size={13}/>Manage project repositories</button>}
                        <div className="st-side-footnote">Uses the authenticated GitHub App OAuth, repository mapping and background sync APIs. Only repositories granted to the installation can be selected.</div>
                      </section>

                      <section className="st-side-panel st-deadlines-panel" id="slack-panel" data-st-reveal>
                        <div className="st-side-panel__heading"><span className="st-panel-icon"><Icon name="chat" size={17}/></span><div><span className="st-section-label">TEAM COMMUNICATION</span><h2>Slack</h2></div><span className="st-panel-count">—</span></div>
                        <div className="st-jira-status-card"><div className="st-jira-status-card__top"><span className="st-jira-indicator"/><strong>Backend setup required</strong></div><p>Slack OAuth, workspace connection and event sync endpoints are not included in the current SynTrace backend.</p><small>No fake connected state or client-side token storage is used.</small></div>
                        <button type="button" className="st-activity-link" disabled aria-disabled="true" title="Slack integration is unavailable until its backend OAuth and event APIs are deployed."><Icon name="info" size={13}/>Slack unavailable · backend setup required</button>
                      </section>

                      <section className="st-side-panel st-meetings-panel" id="meeting-panel" data-st-reveal><div className="st-side-panel__heading"><span className="st-panel-icon"><Icon name="book" size={17}/></span><div><span className="st-section-label">PROJECT KNOWLEDGE</span><h2>Meeting Notes</h2></div><span className="st-panel-count">{meetingNotes.length.toString().padStart(2, '0')}</span></div>
                        {meetingNotes.length ? <div className="st-meeting-agenda">{meetingNotes.slice(0, 4).map((note, index) => { const projectId = String(read(note, 'projectId', 'ProjectId') || ''); const project = projectById.get(projectId); return <button type="button" className="st-agenda-item st-agenda-item--button" key={sourceIdOf(note)} onClick={() => handleOpenMeetingNote(note)}><i className={`st-agenda-accent st-agenda-accent--${toneForIndex(index)}`}/><span><strong>{read(note, 'title', 'Title') || 'Meeting note'}</strong><small>{project ? projectLabel(project) : 'Client-level knowledge'} · {statusText(sourceStatus(note))}</small></span><time>v{read(note, 'version', 'Version') ?? '—'}</time></button>; })}</div> : <EmptyPanel icon="book" title="No meeting notes available" detail="Create a Meeting Notes knowledge source to see it here. The list shows only notes returned to your account by the Knowledge Sources API."/>}
                        <button type="button" className="st-activity-link" disabled={creating || !projects.length} onClick={() => openNav({ id: 'meetings' })}><Icon name="plus" size={13}/>New meeting analysis</button><div className="st-side-footnote">{knowledgeSources.length} accessible knowledge sources total · original content stays separate from AI-extracted evidence</div>
                      </section>

                      <section className="st-activity-panel" data-st-reveal><div className="st-side-panel__heading"><span className="st-panel-icon st-panel-icon--quiet"><Icon name="database" size={17}/></span><div><span className="st-section-label">WORKSPACE COVERAGE</span><h2>Connected records</h2></div></div>
                        <WorkspaceStatus label="Projects" state={loading ? 'Loading' : (resourceStates.projects || 'Unavailable')} detail={resourceErrors.projects || `${projects.length} records returned`}/>
                        <WorkspaceStatus label="Clients" state={loading ? 'Loading' : (resourceStates.clients || 'Unavailable')} detail={resourceErrors.clients || `${clients.length} records returned`}/>
                        <WorkspaceStatus label="Team" state={loading ? 'Loading' : (resourceStates.employees || 'Unavailable')} detail={resourceErrors.employees || `${employees.length} employees returned`}/>
                        <WorkspaceStatus label="Knowledge" state={loading ? 'Loading' : (resourceStates.knowledge || 'Unavailable')} detail={resourceErrors.knowledge || `${knowledgeSources.length} sources returned`}/>
                        <WorkspaceStatus label="GitHub" state={loading ? 'Loading' : (resourceStates.github || 'Unavailable')} detail={githubStatus.accountLogin || githubStatus.error || 'Company App connection status'}/>
                        <button type="button" className="st-activity-link" onClick={reloadWorkspace}><Icon name="refresh" size={13}/> Refresh workspace data</button>
                      </section>
                    </aside>
                  </div>
                  <footer className="st-footer"><span>SynTrace <b>·</b> Connect the work. Understand the context. Trace every decision.</span><span>Authenticated workspace · Company-scoped APIs</span></footer>
                </div>
              )}
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
