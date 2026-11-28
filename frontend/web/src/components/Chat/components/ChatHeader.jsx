import ChatIcon from './ChatIcons.jsx';

export default function ChatHeader({ title, sourceCount = 0, onToggleSources, sourcesOpen, onToggleHistory, onNew }) {
  return (
    <header className="st-chat-header">
      <div className="st-chat-header__title-group">
        <button type="button" className="st-chat-icon-btn st-chat-mobile-menu" onClick={onToggleHistory} aria-label="Open conversations">
          <ChatIcon name="menu" size={18}/>
        </button>
        <div className="st-chat-header__titles">
          <span className="st-chat-header__eyebrow">SYNTRACE / INTELLIGENCE</span>
          <h1 title={title}>{title || 'New conversation'}</h1>
        </div>
      </div>
      <div className="st-chat-header__actions">
        <span className="st-chat-scope" title="The backend limits assistant context to projects accessible to your account">
          <ChatIcon name="folder" size={15}/><span>Accessible workspace</span><ChatIcon name="shield" size={14}/>
        </span>
        <button
          type="button"
          className={`st-chat-header-action ${sourcesOpen ? 'is-active' : ''}`}
          onClick={onToggleSources}
          disabled={!sourceCount}
          title={sourceCount ? 'View cited records' : 'Sources appear when an answer cites records'}
        >
          <ChatIcon name="panel" size={16}/><span>Sources</span>{sourceCount > 0 && <b>{sourceCount}</b>}
        </button>
        <button type="button" className="st-chat-new-compact" onClick={onNew} title="New conversation" aria-label="New conversation">
          <ChatIcon name="pencil" size={16}/><span>New chat</span>
        </button>
      </div>
    </header>
  );
}
