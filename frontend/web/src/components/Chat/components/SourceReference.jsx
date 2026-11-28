import ChatIcon from './ChatIcons.jsx';

const icons = { 'Meeting note': 'note', 'Jira issue': 'jira', Project: 'folder', Sprint: 'layers' };

export default function SourceReference({ source, compact = false, selected = false, onClick }) {
  const content = (
    <>
      <span className={`st-chat-source__icon st-chat-source__icon--${source.tone}`}><ChatIcon name={icons[source.type] || 'file'} size={16}/></span>
      <span className="st-chat-source__content"><small>{source.type} <i/> {source.record}</small><strong>{source.label}</strong>{!compact && <em>{source.snippet}</em>}</span>
      {onClick && <ChatIcon name="arrow" size={14} className="st-chat-source__arrow"/>}
    </>
  );

  if (onClick) return <button type="button" className={`st-chat-source ${compact ? 'is-compact' : ''} ${selected ? 'is-selected' : ''}`} onClick={onClick}>{content}</button>;
  return <div className={`st-chat-source ${compact ? 'is-compact' : ''}`}>{content}</div>;
}
