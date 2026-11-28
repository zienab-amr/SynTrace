import ChatIcon from './ChatIcons.jsx';

const iconFor = (type) => ({
  'Meeting note': 'note',
  'Jira issue': 'jira',
  Project: 'folder',
  Sprint: 'layers',
  Employee: 'users',
  Client: 'folder',
  Decision: 'spark',
}[type] || 'file');

export default function ContextPanel({ sources = [], activeSourceId, onSelectSource, onClose, project }) {
  const activeSource = sources.find((source) => source.id === activeSourceId) || sources[0];

  return (
    <aside className="st-chat-context" aria-label="Cited source records">
      <div className="st-chat-context__header">
        <div><span className="st-chat-context__eyebrow">ANSWER REFERENCES</span><h2>Sources</h2><p>Open a record to inspect its available context.</p></div>
        <button type="button" className="st-chat-icon-btn st-chat-context__close" aria-label="Close sources" onClick={onClose}><ChatIcon name="close" size={16}/></button>
      </div>

      <div className="st-chat-context__scope">
        <span className="st-chat-context__scope-icon"><ChatIcon name="folder" size={16}/></span>
        <span><small>PROJECT CONTEXT</small><strong>{project || 'All workspace'}</strong></span>
      </div>

      <section className="st-chat-context-section">
        <div className="st-chat-context-section__title"><span>CITED RECORDS</span><b>{sources.length}</b></div>
        {sources.length ? (
          <div className="st-chat-source-list">
            {sources.map((source) => (
              <button type="button" key={source.id} className={`st-chat-source-row ${source.id === activeSource?.id ? 'is-selected' : ''}`} onClick={() => onSelectSource(source.id)} aria-pressed={source.id === activeSource?.id}>
                <span className={`st-chat-source-row__icon st-chat-source-row__icon--${source.tone}`}><ChatIcon name={iconFor(source.type)} size={15}/></span>
                <span className="st-chat-source-row__copy"><small>{source.type} · {source.record}</small><strong>{source.label}</strong></span>
                <ChatIcon name="chevron" size={14}/>
              </button>
            ))}
          </div>
        ) : <div className="st-chat-context-empty">No source records are attached to this answer.</div>}
      </section>

      {activeSource && (
        <section className="st-chat-record-detail" key={activeSource.id}>
          <div className="st-chat-context-section__title"><span>RECORD DETAILS</span><span>{activeSource.date}</span></div>
          <div className={`st-chat-record-detail__type st-chat-record-detail__type--${activeSource.tone}`}><ChatIcon name={iconFor(activeSource.type)} size={14}/>{activeSource.type}</div>
          <h3>{activeSource.label}</h3>
          <div className="st-chat-record-detail__meta"><span>{activeSource.record}</span><i/>{activeSource.project}</div>
          <p>{activeSource.snippet}</p>
          {activeSource.url && <a className="st-chat-source-open" href={activeSource.url} target="_blank" rel="noreferrer"><ChatIcon name="external" size={14}/> Open original source</a>}
          <div className="st-chat-record-detail__provenance"><ChatIcon name="shield" size={14}/><span><small>SOURCE</small><strong>{activeSource.provenance}</strong></span></div>
        </section>
      )}

      <div className="st-chat-context-foot"><ChatIcon name="info" size={14}/><span>Sources are returned by the SynTrace Assistant service. Open the original record when a URL is available.</span></div>
    </aside>
  );
}
