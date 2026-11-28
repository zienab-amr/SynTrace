import MessageBubble from './MessageBubble.jsx';

export default function MessageThread({ messages, sourceMap, onSourceSelect, onChoice, userInitials }) {
  const lastMessage = messages[messages.length - 1];
  const canChoose = lastMessage?.role === 'assistant' && lastMessage?.kind === 'backend';
  return (
    <div className="st-chat-thread" aria-live="polite">
      <div className="st-chat-thread__date"><span/>CONVERSATION<span/></div>
      {messages.map((message) => (
        <MessageBubble key={message.id} message={message} sourceMap={sourceMap} onSourceSelect={onSourceSelect} onChoice={canChoose && message.id === lastMessage.id ? onChoice : undefined} userInitials={userInitials}/>
      ))}
    </div>
  );
}
