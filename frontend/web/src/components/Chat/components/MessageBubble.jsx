import { useEffect, useRef, useState } from 'react';
import ChatIcon, { SynTraceMark } from './ChatIcons.jsx';

function AssistantMessage({ message, sourceMap, onSourceSelect }) {
  const [copied, setCopied] = useState(false);
  const copyTimer = useRef(null);
  const citedSources = (message.sourceIds || []).map((id) => sourceMap[id]).filter(Boolean);
  const plainText = message.text || [message.intro, message.summary, ...(message.findings || []).map((item) => `${item.title}. ${item.body}`), ...(message.nextSteps || [])].filter(Boolean).join('\n\n');

  useEffect(() => () => window.clearTimeout(copyTimer.current), []);

  const copyAnswer = async () => {
    try {
      await navigator.clipboard.writeText(plainText);
      setCopied(true);
      window.clearTimeout(copyTimer.current);
      copyTimer.current = window.setTimeout(() => setCopied(false), 1500);
    } catch { setCopied(false); }
  };

  if (message.kind === 'pending') {
    return (
      <article className="st-chat-message st-chat-message--assistant">
        <div className="st-chat-message__avatar"><SynTraceMark size={23}/></div>
        <div className="st-chat-message__body">
          <div className="st-chat-message__byline"><strong>SynTrace Intelligence</strong><span className="st-chat-message__mode">Investigating</span></div>
          <div className="st-chat-local-notice"><span className="st-chat-loading__spinner"/><p>{message.text}</p></div>
        </div>
      </article>
    );
  }

  if (message.kind === 'error') {
    return (
      <article className="st-chat-message st-chat-message--assistant">
        <div className="st-chat-message__avatar"><SynTraceMark size={23}/></div>
        <div className="st-chat-message__body">
          <div className="st-chat-message__byline"><strong>SynTrace Intelligence</strong><span className="st-chat-message__mode">Request failed</span></div>
          <div className="st-chat-local-notice st-chat-error-notice"><ChatIcon name="info" size={16}/><p>{message.text}</p></div>
        </div>
      </article>
    );
  }

  if (message.kind === 'backend') {
    return (
      <article className="st-chat-message st-chat-message--assistant">
        <div className="st-chat-message__avatar"><SynTraceMark size={23}/></div>
        <div className="st-chat-message__body">
          <div className="st-chat-message__byline">
            <strong>SynTrace Intelligence</strong>
            <span className="st-chat-message__mode">Workspace answer</span>
            <button type="button" className="st-chat-copy" onClick={copyAnswer} aria-label="Copy answer" title="Copy answer">
              <ChatIcon name={copied ? 'check' : 'copy'} size={14}/><span>{copied ? 'Copied' : 'Copy'}</span>
            </button>
          </div>
          <div className="st-chat-answer">
            <p className="st-chat-answer__intro" style={{ whiteSpace: 'pre-wrap' }}>{message.text}</p>
            {citedSources.length > 0 && (
              <div className="st-chat-citations">
                <span className="st-chat-citations__label">Sources</span>
                {citedSources.map((source) => (
                  <button type="button" key={source.id} onClick={() => onSourceSelect(source.id)} title={`Open ${source.label}`}>
                    <ChatIcon name="file" size={13}/>{source.record}
                  </button>
                ))}
              </div>
            )}
            <div className="st-chat-answer__footnote"><ChatIcon name="shield" size={13}/> Retrieved using your authenticated workspace access</div>
          </div>
        </div>
      </article>
    );
  }

  return (
    <article className="st-chat-message st-chat-message--assistant">
      <div className="st-chat-message__avatar"><SynTraceMark size={23}/></div>
      <div className="st-chat-message__body">
        <div className="st-chat-message__byline"><strong>SynTrace Intelligence</strong></div>
        <div className="st-chat-answer"><p className="st-chat-answer__intro" style={{ whiteSpace: 'pre-wrap' }}>{plainText}</p></div>
      </div>
    </article>
  );
}

export default function MessageBubble({ message, sourceMap, onSourceSelect, userInitials = 'ST' }) {
  if (message.role === 'assistant') return <AssistantMessage message={message} sourceMap={sourceMap} onSourceSelect={onSourceSelect}/>;
  return (
    <article className="st-chat-message st-chat-message--user">
      <div className="st-chat-message__body">
        <div className="st-chat-message__byline"><span>You</span><time>{message.time || 'Just now'}</time></div>
        <div className="st-chat-user-bubble">{message.text}</div>
      </div>
      <div className="st-chat-user-avatar">{userInitials}</div>
    </article>
  );
}
