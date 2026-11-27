import { useRef, useState } from 'react';
import ChatIcon from './ChatIcons.jsx';

export default function ChatComposer({ onSend, disabled = false, scope = 'your workspace' }) {
  const [value, setValue] = useState('');
  const textareaRef = useRef(null);

  const submit = () => {
    const text = value.trim();
    if (!text || disabled) return;
    onSend(text);
    setValue('');
    if (textareaRef.current) textareaRef.current.style.height = 'auto';
  };

  const handleKeyDown = (event) => {
    if (event.key === 'Enter' && !event.shiftKey && !event.nativeEvent.isComposing) {
      event.preventDefault();
      submit();
    }
  };

  const resize = (event) => {
    setValue(event.target.value);
    event.target.style.height = 'auto';
    event.target.style.height = `${Math.min(event.target.scrollHeight, 132)}px`;
  };

  return (
    <div className="st-chat-composer-wrap">
      <div className="st-chat-composer">
        <textarea
          ref={textareaRef}
          rows={1}
          value={value}
          onChange={resize}
          onKeyDown={handleKeyDown}
          placeholder={`Ask about ${scope.toLowerCase()}…`}
          aria-label="Message SynTrace Intelligence"
          maxLength={2000}
          disabled={disabled}
        />
        <div className="st-chat-composer__toolbar">
          <span className="st-chat-source-toggle is-on" title="Project access is determined by backend authorization">
            <ChatIcon name="shield" size={14}/><span>Company-scoped context</span><i/>
          </span>
          <span className="st-chat-composer__hint">Enter to send · Shift + Enter for a new line</span>
          <button type="button" className="st-chat-send" onClick={submit} disabled={!value.trim() || disabled} aria-label="Send message">
            <ChatIcon name="send" size={16}/>
          </button>
        </div>
      </div>
    </div>
  );
}
