import MessageBubble from './MessageBubble.jsx';

export default function MessageThread({ messages, sourceMap, onSourceSelect, userInitials }) {
  return (
    <div className="st-chat-thread" aria-live="polite">
      <div className="st-chat-thread__date"><span/>CONVERSATION<span/></div>
      {messages.map((message) => (
        <MessageBubble key={message.id} message={message} sourceMap={sourceMap} onSourceSelect={onSourceSelect} userInitials={userInitials}/>
      ))}
    </div>
  );
}
