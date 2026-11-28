import { assetUrl } from '../../../lib/assetUrl.js';
import ChatIcon from './ChatIcons.jsx';

const groups = ['Today', 'Yesterday', 'Earlier'];

export default function ChatSidebar({ conversations, activeId, search, setSearch, onSelect, onNew, onClose }) {
  const term = search.trim().toLowerCase();
  const matches = conversations.filter((item) => !term || `${item.title} ${item.project}`.toLowerCase().includes(term));

  return (
    <aside className="st-chat-sidebar" aria-label="Conversation history">
      <div className="st-chat-sidebar__top">
        <div className="st-chat-sidebar__brand">
          <span className="st-chat-sidebar__brand-mark"><img src={assetUrl('assets/syntrace-mark.webp')} alt="" aria-hidden="true" draggable="false"/></span>
          <span><strong>SynTrace</strong><small>AI Assistant</small></span>
          <button type="button" className="st-chat-icon-btn st-chat-sidebar__close" aria-label="Close conversation list" onClick={onClose}>
            <ChatIcon name="close" size={16}/>
          </button>
        </div>
        <button type="button" className="st-chat-new-btn" onClick={onNew}>
          <ChatIcon name="plus" size={16}/> New conversation
        </button>
        <label className="st-chat-list-search">
          <ChatIcon name="search" size={15}/>
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search conversations" aria-label="Search conversations"/>
          {search && <button type="button" aria-label="Clear search" onClick={() => setSearch('')}><ChatIcon name="close" size={13}/></button>}
        </label>
      </div>

      <div className="st-chat-history">
        {groups.map((group) => {
          const items = matches.filter((item) => !item.pinned && item.group === group);
          if (!items.length) return null;
          return (
            <section className="st-chat-history-group" key={group}>
              <div className="st-chat-history-group__label">{group}</div>
              {items.map((item) => (
                <button type="button" key={item.id} className={`st-chat-history-item ${activeId === item.id ? 'is-active' : ''}`} onClick={() => onSelect(item.id)}>
                  <ChatIcon name="message" size={15}/>
                  <span className="st-chat-history-item__copy"><strong>{item.title}</strong><small>{item.project}</small></span>
                  {activeId === item.id && <span className="st-chat-history-item__active"/>}
                </button>
              ))}
            </section>
          );
        })}
        {!matches.length && <div className="st-chat-history-empty"><ChatIcon name={conversations.length ? 'search' : 'message'} size={18}/><strong>{conversations.length ? 'No conversations found' : 'No conversations yet'}</strong><span>{conversations.length ? 'Try another keyword.' : 'Start a new conversation to save your first question.'}</span></div>}
      </div>

      <div className="st-chat-sidebar__foot"><span className="st-chat-status-dot"/><span>Workspace context is kept company-scoped.</span></div>
    </aside>
  );
}
