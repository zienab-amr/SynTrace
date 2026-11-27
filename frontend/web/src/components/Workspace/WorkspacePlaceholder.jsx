import { useEffect, useMemo, useRef, useState } from 'react';
import ThemeToggle from '../common/ThemeToggle.jsx';
import { useAuth } from '../../context/AuthContext.jsx';
import { navigate } from '../../router/router.jsx';
import './workspace-dashboard.css';

const deadlines = [
  { title: 'Payment provider migration', project: 'ERP Platform', due: 'Today · 4:30 PM', progress: 68, state: 'At risk', tone: 'blue' },
  { title: 'QA environment handoff', project: 'Atlas CRM', due: 'Tomorrow · 11:00 AM', progress: 42, state: 'In progress', tone: 'mint' },
];

const workItems = [
  { id: 'ERP-142', title: 'Review payment provider dependency', project: 'ERP Platform', day: 1, span: 2, row: 1, tone: 'blue', state: 'Blocked', time: '09:30', detail: 'External dependency is delaying the migration.' },
  { id: 'ATL-088', title: 'QA environment handoff', project: 'Atlas CRM', day: 4, span: 2, row: 1, tone: 'mint', state: 'In progress', time: '11:00', detail: 'Prepare the environment for the next validation cycle.' },
  { id: 'ERP-151', title: 'Checkout API contract review', project: 'ERP Platform', day: 2, span: 3, row: 2, tone: 'orange', state: 'Review', time: '12:15', detail: 'Review the updated checkout contract with the team.' },
  { id: 'MBK-206', title: 'Confirm API contract', project: 'Mobile Banking', day: 5, span: 2, row: 2, tone: 'violet', state: 'Planned', time: '02:00', detail: 'Confirm the API contract before implementation.' },
  { id: 'ERP-156', title: 'Regression test · payment flow', project: 'ERP Platform', day: 1, span: 3, row: 3, tone: 'pink', state: 'Planned', time: '03:30', detail: 'Validate the payment flow after the provider changes.' },
];

const activity = [
  { title: 'Issue moved to Blocked', detail: 'ERP-142 · ERP Platform', time: '11:40 AM', tone: 'blue' },
  { title: 'Planning note added', detail: 'Sprint 24 · Meeting Notes', time: '10:15 AM', tone: 'mint' },
  { title: 'Project assignment updated', detail: 'Atlas CRM · Team', time: 'Yesterday', tone: 'violet' },
];

const chartValues = [
  { label: 'W1', open: 42, closed: 28 },
  { label: 'W2', open: 66, closed: 46 },
  { label: 'W3', open: 53, closed: 43 },
  { label: 'W4', open: 81, closed: 61 },
  { label: 'W5', open: 72, closed: 59 },
  { label: 'W6', open: 93, closed: 74 },
  { label: 'W7', open: 62, closed: 52 },
];

const days = [
  { date: '23', name: 'Mon' }, { date: '24', name: 'Tue' }, { date: '25', name: 'Wed' },
  { date: '26', name: 'Thu' }, { date: '27', name: 'Fri' }, { date: '28', name: 'Sat' }, { date: '29', name: 'Sun' },
];

function Icon({ name, size = 18, strokeWidth = 1.7 }) {
  const common = { fill: 'none', stroke: 'currentColor', strokeWidth, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const paths = {
    grid: <><rect x="4" y="4" width="6" height="6" rx="1.4"/><rect x="14" y="4" width="6" height="6" rx="1.4"/><rect x="4" y="14" width="6" height="6" rx="1.4"/><rect x="14" y="14" width="6" height="6" rx="1.4"/></>,
    chat: <><path d="M20 11.5a7.5 7.5 0 0 1-7.5 7.5H6l-3 2v-6.5A7.5 7.5 0 1 1 20 11.5Z"/><path d="M8 11h8M8 14h5"/></>,
    graph: <><circle cx="12" cy="5" r="2.2"/><circle cx="5" cy="18" r="2.2"/><circle cx="19" cy="18" r="2.2"/><circle cx="12" cy="13" r="2.2"/><path d="m10.8 7-4.6 9M13.2 7l4.6 9M7.2 18h9.6M12 7.3v3.4"/></>,
    folder: <><path d="M3 7.5a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v8.8a2.2 2.2 0 0 1-2.2 2.2H5.2A2.2 2.2 0 0 1 3 18.3Z"/><path d="M3.5 9h17"/></>,
    tasks: <><rect x="4" y="4" width="16" height="16" rx="3"/><path d="m8 12 2.5 2.5L16 9M8 7.5h.01M8 17h.01"/></>,
    calendar: <><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M7 3v4M17 3v4M3 9.5h18M7.5 13h3M14 13h3M7.5 17h3"/></>,
    users: <><path d="M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20M10 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7ZM17 4.5a3.5 3.5 0 0 1 0 6.8M20 20v-1.5a3.5 3.5 0 0 0-2.5-3.35"/></>,
    settings: <><circle cx="12" cy="12" r="3"/><path d="m19.4 15 .1.1a1.7 1.7 0 0 1-2.4 2.4l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a1.7 1.7 0 0 1-3.4 0v-.2a1.7 1.7 0 0 0-2.9-1.2l-.1.1a1.7 1.7 0 1 1-2.4-2.4l.1-.1a1.7 1.7 0 0 0-1.2-2.9H4a1.7 1.7 0 0 1 0-3.4h.2a1.7 1.7 0 0 0 1.2-2.9l-.1-.1a1.7 1.7 0 1 1 2.4-2.4l.1.1a1.7 1.7 0 0 0 2.9-1.2V2a1.7 1.7 0 0 1 3.4 0v.2a1.7 1.7 0 0 0 2.9 1.2l.1-.1a1.7 1.7 0 1 1 2.4 2.4l-.1.1a1.7 1.7 0 0 0 1.2 2.9h.2a1.7 1.7 0 0 1 0 3.4h-.2a1.7 1.7 0 0 0-1.2 2.9Z"/></>,
    help: <><circle cx="12" cy="12" r="9"/><path d="M9.6 9a2.5 2.5 0 1 1 4.4 1.6c-1.2 1.3-2 1.5-2 3.1M12 17h.01"/></>,
    search: <><circle cx="10.8" cy="10.8" r="6.8"/><path d="m16 16 4.5 4.5"/></>,
    bell: <><path d="M18 9a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/></>,
    chevron: <path d="m8 10 4 4 4-4"/>,
    arrow: <><path d="M5 12h14M13 6l6 6-6 6"/></>,
    arrowUp: <><path d="m7 14 5-5 5 5M12 9v11"/></>,
    more: <><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></>,
    clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
    check: <path d="m5 12 4.2 4.2L19 6.5"/>,
    alert: <><path d="M10.3 4.5 2.9 17.2A2 2 0 0 0 4.6 20h14.8a2 2 0 0 0 1.7-2.8L13.7 4.5a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 16.5h.01"/></>,
    spark: <><path d="m12 3 1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3Z"/><path d="m19 15 .9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9L19 15Z"/></>,
    sliders: <><path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="2" fill="currentColor" stroke="none"/><circle cx="11" cy="18" r="2" fill="currentColor" stroke="none"/></>,
    filter: <><path d="M4 5h16l-6.5 7.5v5l-3 1.5v-6.5Z"/></>,
    plus: <path d="M12 5v14M5 12h14"/>,
    sun: <><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></>,
    close: <><path d="m6 6 12 12M18 6 6 18"/></>,
    logout: <><path d="M10 17l5-5-5-5M15 12H3"/><path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6"/></>,
    link: <><path d="M10 13a5 5 0 0 0 7.1 0l2-2A5 5 0 0 0 12 3.9l-1.1 1.1"/><path d="M14 11a5 5 0 0 0-7.1 0l-2 2A5 5 0 0 0 12 20.1l1.1-1.1"/></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" {...common}>{paths[name] || paths.grid}</svg>;
}

function initialsFor(user) {
  const value = user?.name || user?.email?.split('@')[0] || 'ST';
  return value.split(/[\s._-]+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
}

function BarChart() {
  return (
    <div className="st-bars" aria-label="Illustrative issue activity over seven weeks">
      <div className="st-bars__scale"><span>100</span><span>75</span><span>50</span><span>25</span><span>0</span></div>
      <div className="st-bars__plot">
        <div className="st-bars__grid"><i/><i/><i/><i/><i/></div>
        <div className="st-bars__columns">
          {chartValues.map((value) => (
            <div className="st-bars__group" key={value.label}>
              <div className="st-bars__pair">
                <span className="st-bars__bar st-bars__bar--opened" style={{ height: `${value.open}%` }} title={`${value.open} opened (demo)`}/>
                <span className="st-bars__bar st-bars__bar--closed" style={{ height: `${value.closed}%` }} title={`${value.closed} resolved (demo)`}/>
              </div>
              <small>{value.label}</small>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function TaskCalendar({ query, selectedId, onSelect }) {
  const filtered = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) return workItems;
    return workItems.filter((item) => [item.id, item.title, item.project, item.state].some((part) => part.toLowerCase().includes(term)));
  }, [query]);

  return (
    <div className="st-calendar" id="task-calendar">
      <div className="st-calendar__days">
        {days.map((day) => <div className="st-calendar__day" key={day.date}><strong>{day.date}</strong><span>{day.name}</span></div>)}
      </div>
      <div className="st-calendar__body">
        <div className="st-calendar__gridlines">{days.map((day) => <i key={day.date}/>)}</div>
        <div className="st-calendar__events">
          {filtered.map((item) => (
            <button
              type="button"
              key={item.id}
              className={`st-event st-event--${item.tone} ${selectedId === item.id ? 'is-selected' : ''}`}
              style={{ gridColumn: `${item.day} / span ${item.span}`, gridRow: item.row }}
              onClick={() => onSelect(item.id)}
            >
              <span className="st-event__mark"><Icon name={item.state === 'Blocked' ? 'alert' : item.state === 'In progress' ? 'clock' : 'check'} size={14}/></span>
              <span className="st-event__copy"><small>{item.id} · {item.project}</small><strong>{item.title}</strong></span>
              <span className="st-event__more"><Icon name="more" size={15}/></span>
            </button>
          ))}
          {filtered.length === 0 && <div className="st-calendar__empty">No demo tasks match “{query}”.</div>}
        </div>
      </div>
      <div className="st-calendar__foot"><span><i className="st-legend-dot st-legend-dot--blue"/> Jira work items</span><span><i className="st-legend-dot st-legend-dot--mint"/> Team activities</span><span className="st-calendar__note">Illustrative schedule · demo data</span></div>
    </div>
  );
}

export default function WorkspacePlaceholder({ previewMode = false }) {
  const { user, logout } = useAuth();
  const displayUser = previewMode ? { name: 'Demo Admin', email: 'demo@syntrace.local', role: 'Admin' } : user;
  const [query, setQuery] = useState('');
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [aiOpen, setAiOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [activeNav, setActiveNav] = useState('overview');
  const [selectedId, setSelectedId] = useState('ERP-142');
  const searchRef = useRef(null);
  const selectedItem = workItems.find((item) => item.id === selectedId) || workItems[0];
  const displayName = displayUser?.name || displayUser?.email?.split('@')[0] || 'Workspace member';
  const initials = initialsFor(displayUser);
  const today = new Intl.DateTimeFormat('en-US', { weekday: 'short', month: 'short', day: 'numeric' }).format(new Date());

  useEffect(() => {
    const onKey = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        searchRef.current?.focus();
      }
      if (event.key === 'Escape') {
        setNotificationsOpen(false);
        setCreateOpen(false);
        setAiOpen(false);
        setProfileOpen(false);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const jumpTo = (id, nav) => {
    setActiveNav(nav);
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  };

  const handleSignOut = async () => {
    if (previewMode) {
      navigate('/', { replace: true });
      return;
    }
    await logout();
    navigate('/login', { replace: true });
  };

  const navItems = [
    { id: 'overview', icon: 'grid', label: 'Overview', target: 'workspace-overview' },
    { id: 'assistant', icon: 'chat', label: 'AI Assistant', target: 'assistant-prompt' },
    { id: 'graph', icon: 'graph', label: 'Knowledge Graph', target: 'decision-context' },
    { id: 'projects', icon: 'folder', label: 'Projects', target: 'project-activity' },
    { id: 'tasks', icon: 'tasks', label: 'Tasks', target: 'task-calendar' },
    { id: 'meetings', icon: 'calendar', label: 'Meetings', target: 'meeting-panel' },
  ];

  return (
    <main className="st-stage">
      <div className="st-frame">
        <header className="st-topbar">
          <div className="st-topbar__brand-area">
            <a className="st-brand" href="#workspace-overview" onClick={(event) => { event.preventDefault(); jumpTo('workspace-overview', 'overview'); }} aria-label="SynTrace home">
              <img src="/assets/syntrace-mark.webp" alt="" />
            </a>
            <div className="st-workspace-switcher"><span className="st-workspace-symbol">S</span><span><strong>SynTrace</strong><small>Enterprise workspace</small></span><Icon name="chevron" size={14}/></div>
            <button type="button" className={`st-ai-launch ${aiOpen ? 'is-open' : ''}`} onClick={() => setAiOpen((open) => !open)}><span className="st-ai-launch__icon"><Icon name="spark" size={15}/></span><span>AI Assistant</span><i>Preview</i></button>
            {aiOpen && <div className="st-ai-popover"><span className="st-popover-kicker">SYNTRACE INTELLIGENCE</span><strong>Ask about your workspace</strong><p>Explore project context across connected sources. This local preview uses illustrative records.</p><div className="st-ai-example">“Why is ERP-142 blocked?” <Icon name="arrow" size={14}/></div></div>}
          </div>

          <label className="st-search"><Icon name="search" size={17}/><input ref={searchRef} value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search projects, issues, people…" aria-label="Search demo project records"/><kbd>⌘ K</kbd></label>

          <div className="st-topbar__tools">
            <div className="st-dropdown-anchor">
              <button type="button" className={`st-round-button ${notificationsOpen ? 'is-active' : ''}`} aria-label="Notifications" onClick={() => { setNotificationsOpen((open) => !open); setProfileOpen(false); }}><Icon name="bell" size={17}/><i/></button>
              {notificationsOpen && <div className="st-popover st-notification-popover"><div className="st-popover__head"><strong>Notifications</strong><span>Demo</span></div><div className="st-notification-item"><span className="st-notification-mark st-notification-mark--blue"><Icon name="alert" size={14}/></span><div><strong>ERP-142 needs attention</strong><small>Payment provider dependency · Just now</small></div></div><div className="st-notification-item"><span className="st-notification-mark st-notification-mark--mint"><Icon name="calendar" size={14}/></span><div><strong>Planning note processed</strong><small>Sprint 24 · 10:15 AM</small></div></div><p>Sample notifications. Live alerts appear when workspace events are connected.</p></div>}
            </div>
            <ThemeToggle className="st-theme-toggle" />
            <div className="st-dropdown-anchor">
              <button type="button" className="st-profile-button" onClick={() => { setProfileOpen((open) => !open); setNotificationsOpen(false); }} aria-label="Open profile menu"><span>{initials}</span></button>
              {profileOpen && <div className="st-popover st-profile-popover"><strong>{displayName}</strong><small>{displayUser?.email}</small><span className="st-profile-role">{displayUser?.role || 'Workspace member'}</span><button type="button" onClick={handleSignOut}><Icon name="logout" size={15}/> {previewMode ? 'Exit preview' : 'Sign out'}</button></div>}
            </div>
          </div>
        </header>

        <div className="st-frame__body">
          <aside className="st-rail" aria-label="Workspace navigation">
            <div className="st-rail__primary">
              {navItems.map((item) => <button key={item.id} type="button" title={item.label} aria-label={item.label} className={`st-rail__item ${activeNav === item.id ? 'is-active' : ''}`} onClick={() => jumpTo(item.target, item.id)}><Icon name={item.icon} size={19}/></button>)}
            </div>
            <div className="st-rail__bottom"><button type="button" className="st-rail__item" title="Settings" aria-label="Settings"><Icon name="settings" size={19}/></button><button type="button" className="st-rail__item" title="Help" aria-label="Help"><Icon name="help" size={19}/></button></div>
          </aside>

          <section className="st-workspace" id="workspace-overview">
            <div className="st-workspace__scroll">
              <section className="st-project-heading">
                <div className="st-project-heading__left">
                  <div className="st-breadcrumb"><span>Workspace</span><b>/</b><strong>Project overview</strong></div>
                  <div className="st-title-line"><div><span className="st-eyebrow">PROJECT INTELLIGENCE</span><h1>Engineering Portfolio</h1></div><span className="st-demo-tag"><i/> LOCAL DEMO</span></div>
                </div>
                <div className="st-project-actions">
                  <button type="button" className="st-text-action" onClick={() => jumpTo('project-activity', 'projects')}><Icon name="sliders" size={15}/> Manage</button>
                  <button type="button" className="st-text-action" onClick={() => setCreateOpen((open) => !open)}><Icon name="more" size={16}/> Actions</button>
                  <div className="st-avatars" aria-label="Sample collaborators"><span>ZA</span><span>RA</span><span>FH</span><b>+4</b></div>
                  <div className="st-dropdown-anchor"><button type="button" className="st-new-button" onClick={() => setCreateOpen((open) => !open)}>New <Icon name="chevron" size={14}/></button>
                    {createOpen && <div className="st-popover st-create-popover"><strong>Create in SynTrace</strong><button type="button" onClick={() => { setCreateOpen(false); setAiOpen(true); }}><Icon name="tasks" size={15}/> New work item <small>Preview only</small></button><button type="button" onClick={() => { setCreateOpen(false); jumpTo('meeting-panel', 'meetings'); }}><Icon name="calendar" size={15}/> Meeting note <small>In development</small></button></div>}
                  </div>
                </div>
              </section>

              <section className="st-summary-row" aria-label="Workspace summary">
                <div className="st-summary-stat"><small>Projects</small><strong>12</strong><span>Active</span></div>
                <div className="st-summary-stat"><small>Open issues</small><strong>45</strong><span>Across Jira</span></div>
                <div className="st-summary-stat"><small>Team members</small><strong>08</strong><span>In workspace</span></div>
                <div className="st-summary-stat st-summary-stat--quiet"><small>Last activity</small><strong>{today}</strong><span>Illustrative activity</span></div>
              </section>

              <div className="st-dashboard-grid">
                <div className="st-dashboard-main">
                  <section className="st-insight-panel" id="project-activity">
                    <div className="st-panel-title-row"><div><span className="st-section-label">PROJECT OVERVIEW</span><h2>Project activity</h2></div><button type="button" className="st-utility-button"><span>Last 7 weeks</span><Icon name="chevron" size={14}/></button></div>
                    <div className="st-insight-content">
                      <div className="st-activity-chart"><div className="st-chart-title"><strong>Work movement</strong><span>Opened vs. resolved issues</span></div><BarChart/><div className="st-chart-legend"><span><i className="st-legend-dot st-legend-dot--blue"/> Opened</span><span><i className="st-legend-dot st-legend-dot--mint"/> Resolved</span></div></div>
                      <div className="st-progress-overview">
                        <div className="st-progress-ring"><div className="st-progress-ring__inner"><strong>74<small>%</small></strong><span>Task progress</span></div></div>
                        <span className="st-ring-caption"><i/> Workspace completion</span>
                        <div className="st-progress-counts"><div><strong>146</strong><small>Work items</small></div><div><strong>108</strong><small>Closed</small></div></div>
                      </div>
                    </div>
                    <div className="st-activity-track"><div className="st-activity-track__line"><i/></div><span className="st-track-point st-track-point--start"/><span className="st-track-point st-track-point--middle"/><span className="st-track-point st-track-point--end"/><div className="st-track-label st-track-label--left"><small>START</small><strong>Oct 31</strong></div><div className="st-track-label st-track-label--middle"><small>MIDPOINT</small><strong>Nov 16</strong></div><div className="st-track-label st-track-label--right"><small>REVIEW</small><strong>Dec 23</strong></div></div>
                    <div className="st-panel-footnote">Illustrative workspace metrics · Replace with connected Jira and project data</div>
                  </section>

                  <section className="st-calendar-panel" aria-label="Tasks calendar">
                    <div className="st-calendar-toolbar">
                      <div className="st-calendar-toolbar__title"><h2>Tasks</h2><button type="button" className="st-month-control"><Icon name="chevron" size={13}/><strong>November</strong><Icon name="chevron" size={13}/></button></div>
                      <div className="st-calendar-toolbar__actions"><button type="button" className="st-calendar-tool"><Icon name="sliders" size={14}/> Status</button><button type="button" className="st-calendar-tool"><Icon name="grid" size={14}/> View</button><button type="button" className="st-calendar-tool" onClick={() => searchRef.current?.focus()}><Icon name="filter" size={14}/> Filter</button></div>
                    </div>
                    <TaskCalendar query={query} selectedId={selectedId} onSelect={setSelectedId}/>
                    <div className="st-task-detail" id="decision-context">
                      <div className="st-task-detail__top"><div><small>{selectedItem.project} · {selectedItem.id}</small><strong>{selectedItem.title}</strong></div><button type="button" aria-label="Select current issue" onClick={() => setSelectedId('ERP-142')}><Icon name="close" size={15}/></button></div>
                      <div className="st-task-detail__tags"><span className={`st-mini-status st-mini-status--${selectedItem.tone}`}>{selectedItem.state}</span><span className="st-mini-source"><Icon name="link" size={12}/> Jira record</span></div>
                      <div className="st-task-context"><span>Meeting</span><i/><span>{selectedItem.id}</span><i/><span>{selectedItem.project}</span></div>
                      <p>{selectedItem.detail}</p>
                      <div className="st-task-detail__bottom"><div className="st-mini-avatars"><span>ZA</span><span>RA</span><b>+2</b></div><span className="st-detail-progress"><i style={{ width: selectedItem.state === 'Blocked' ? '42%' : selectedItem.state === 'In progress' ? '68%' : '76%' }}/></span></div>
                    </div>
                  </section>


                </div>

                <aside className="st-right-column">
                  <section className="st-side-panel st-deadlines-panel" id="assistant-panel">
                    <div className="st-side-panel__heading"><span className="st-panel-icon"><Icon name="clock" size={17}/></span><h2>Deadlines</h2><button type="button" className="st-more-button" aria-label="Deadline options"><Icon name="more" size={17}/></button></div>
                    <button type="button" className="st-ai-banner" id="assistant-prompt" onClick={() => setAiOpen((open) => !open)}><span className="st-ai-banner__orb"><Icon name="spark" size={25}/></span><span className="st-ai-banner__copy"><small>PROJECT INTELLIGENCE</small><strong>Investigate with SynTrace</strong><em>Explore connected context <Icon name="arrow" size={13}/></em></span><span className="st-ai-banner__mesh"/></button>
                    <div className="st-deadline-list">{deadlines.map((item) => <div className="st-deadline-item" key={item.title}><div className={`st-deadline-avatar st-deadline-avatar--${item.tone}`}>{item.project.slice(0, 1)}</div><div className="st-deadline-item__body"><div className="st-deadline-item__heading"><small>{item.project}</small><span>{item.progress}%</span></div><strong>{item.title}</strong><div className="st-deadline-progress"><i className={`st-deadline-progress__fill st-deadline-progress__fill--${item.tone}`} style={{ width: `${item.progress}%` }}/></div><small className="st-deadline-due">{item.due}</small></div></div>)}</div>
                    <div className="st-side-footnote"><i/> Sample deadlines · Not connected to a live calendar</div>
                  </section>

                  <section className="st-side-panel st-meetings-panel" id="meeting-panel">
                    <div className="st-side-panel__heading"><span className="st-panel-icon"><Icon name="users" size={17}/></span><h2>Meetings</h2><button type="button" className="st-more-button" aria-label="Meeting options"><Icon name="more" size={17}/></button></div>
                    <div className="st-meeting-feature"><strong>Weekly engineering briefing</strong><div className="st-meeting-meta"><span className="st-meeting-status">Planned</span><span><Icon name="calendar" size={13}/> Dec 01</span><span><Icon name="clock" size={13}/> 10:30 AM</span></div></div>
                    <div className="st-meeting-agenda"><div className="st-agenda-item"><i className="st-agenda-accent st-agenda-accent--blue"/><span><strong>Project risk review</strong><small>ERP Platform · Discuss blockers</small></span><time>10:30</time><span className="st-agenda-icon"><Icon name="spark" size={13}/></span></div><div className="st-agenda-item"><i className="st-agenda-accent st-agenda-accent--mint"/><span><strong>Sprint planning</strong><small>Atlas CRM · Confirm priorities</small></span><time>11:15</time><span className="st-agenda-icon"><Icon name="spark" size={13}/></span></div></div>
                    <div className="st-side-footnote">Meeting schedule preview · Meeting Notes in development</div>
                  </section>


                </aside>
              </div>
              <footer className="st-footer"><span>SynTrace <b>·</b> Project intelligence workspace</span><span>Local preview · Illustrative data only</span></footer>
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
