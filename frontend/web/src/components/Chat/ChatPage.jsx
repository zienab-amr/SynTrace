import { useEffect, useMemo, useRef, useState } from 'react';
import ChatIcon, { SynTraceMark } from './components/ChatIcons.jsx';
import ChatSidebar from './components/ChatSidebar.jsx';
import ChatHeader from './components/ChatHeader.jsx';
import MessageThread from './components/MessageThread.jsx';
import ChatComposer from './components/ChatComposer.jsx';
import ContextPanel from './components/ContextPanel.jsx';
import { listConversations, getConversationMessages, askAssistant } from '../../services/workspaceService.js';
import { getMeetingPermissions } from '../../services/meetingAIService.js';
import { suggestedPrompts } from './data/chatDemoData.js';
import './chat.css';

function localDateValue() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

function initialsFor(user) {
  const value = user?.name || user?.email?.split('@')[0] || 'ST';
  return value.split(/[\s._-]+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
}

function uuid() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (char) => {
    const random = Math.floor(Math.random() * 16);
    return (char === 'x' ? random : (random & 0x3) | 0x8).toString(16);
  });
}

function read(value, camel, pascal) { return value?.[camel] ?? value?.[pascal]; }
function unwrapPayload(value) {
  let current = value;
  for (let depth = 0; depth < 3; depth += 1) {
    if (!current || typeof current !== 'object' || Array.isArray(current)) break;
    const nested = current.data ?? current.result ?? current.payload;
    if (!nested || nested === current) break;
    current = nested;
  }
  return current;
}
function unwrapItems(value, keys = []) {
  const current = unwrapPayload(value);
  if (Array.isArray(current)) return current;
  for (const key of [...keys, 'items', 'results']) {
    if (Array.isArray(current?.[key])) return current[key];
  }
  return [];
}
function formatTime(value) {
  if (!value) return 'Just now';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'Just now' : date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}
function dateGroup(value) {
  const date = new Date(value || 0);
  if (Number.isNaN(date.getTime())) return 'Earlier';
  const start = new Date(); start.setHours(0, 0, 0, 0);
  const yesterday = new Date(start); yesterday.setDate(start.getDate() - 1);
  if (date >= start) return 'Today';
  if (date >= yesterday) return 'Yesterday';
  return 'Earlier';
}
function mapConversation(raw) {
  const id = read(raw, 'id', 'Id') || read(raw, 'conversationId', 'ConversationId');
  const updatedAt = read(raw, 'updatedAt', 'UpdatedAt') || read(raw, 'lastActivityAt', 'LastActivityAt') || read(raw, 'createdAt', 'CreatedAt');
  return {
    id,
    title: read(raw, 'title', 'Title') || 'Conversation',
    project: 'Accessible workspace',
    group: dateGroup(updatedAt),
    updated: formatTime(updatedAt),
    pinned: false,
    messages: [],
    isDraft: false,
  };
}
function mapLinks(links, messageId) {
  return (Array.isArray(links) ? links : []).map((link, index) => {
    const key = read(link, 'key', 'Key') || `Source ${index + 1}`;
    const rawUrl = read(link, 'url', 'Url') || '';
    let url = '';
    try {
      const parsed = new URL(rawUrl);
      if (parsed.protocol === 'https:') url = parsed.href;
    } catch { /* A source key can be useful even when no safe browser URL is returned. */ }
    const id = `${messageId}-source-${index}`;
    const isJira = /^[A-Z][A-Z0-9]+-\d+$/.test(key);
    return {
      id,
      type: isJira ? 'Jira reference' : 'Source reference',
      label: key,
      record: key,
      project: 'Accessible workspace',
      date: 'Referenced in this answer',
      snippet: url ? 'This source link was returned by the SynTrace Assistant service.' : 'The assistant returned this source key without a browser URL.',
      provenance: 'Assistant source reference',
      url,
      tone: isJira ? 'blue' : 'mint',
    };
  });
}
function errorText(error) {
  const data = error?.data;
  if (typeof data?.detail === 'string') return data.detail;
  if (typeof data?.message === 'string') return data.message;
  if (typeof data?.title === 'string') return data.title;
  if (error?.status === 403) return 'Your account does not currently have any accessible projects for the assistant. Ask your company administrator to assign you to a project.';
  if (error?.status === 503) return 'The AI service is currently unavailable. Check the backend and AI worker services, then try again.';
  if (error?.status === 429) return 'The assistant request limit has been reached. Please wait a moment and try again.';
  if (error?.name === 'TypeError') return 'Could not reach the SynTrace API. Check that the backend is running and VITE_API_URL points to it.';
  return error?.message || 'The request could not be completed. Please try again.';
}
function newDraft() {
  return {
    id: `draft-${uuid()}`,
    title: 'New conversation',
    project: 'Accessible workspace',
    group: 'Today',
    updated: 'Just now',
    pinned: false,
    messages: [],
    isDraft: true,
  };
}
function mapServerMessages(items) {
  const sourceMap = {};
  const messages = [];
  unwrapItems(items, ['messages', 'conversationMessages']).forEach((raw) => {
    const id = read(raw, 'id', 'Id');
    const question = read(raw, 'question', 'Question') || '';
    const answer = read(raw, 'answer', 'Answer') || '';
    const status = String(read(raw, 'status', 'Status') || 'pending').toLowerCase();
    const createdAt = read(raw, 'createdAt', 'CreatedAt');
    const links = mapLinks(read(raw, 'links', 'Links'), id);
    links.forEach((source) => { sourceMap[source.id] = source; });
    messages.push({ id: `${id}-question`, role: 'user', text: question, time: formatTime(createdAt) });
    const meeting = read(raw, 'meeting', 'Meeting') || null;
    const choices = read(raw, 'choices', 'Choices') || read(meeting, 'choices', 'Choices') || [];
    messages.push({
      id,
      role: 'assistant',
      kind: status === 'answered' ? 'backend' : status === 'failed' ? 'error' : 'pending',
      text: answer || (status === 'failed' ? 'This answer could not be generated. You can send the question again.' : 'The request is still being processed.'),
      status,
      sourceIds: links.map((source) => source.id),
      choices: Array.isArray(choices) ? choices : [],
      meeting,
      time: formatTime(createdAt),
    });
  });
  return { messages, sourceMap };
}

export default function ChatPage({ currentUser }) {
  const [conversations, setConversations] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [historySearch, setHistorySearch] = useState('');
  const [contextOpen, setContextOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [selectedSourceId, setSelectedSourceId] = useState('');
  const [sourceMap, setSourceMap] = useState({});
  const [loadingHistory, setLoadingHistory] = useState(true);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [sending, setSending] = useState(false);
  const [meetingMode, setMeetingMode] = useState(false);
  const [meetingTranscript, setMeetingTranscript] = useState('');
  const [meetingDate, setMeetingDate] = useState(localDateValue);
  const [meetingPermissions, setMeetingPermissions] = useState([]);
  const [meetingPermissionLoading, setMeetingPermissionLoading] = useState(true);
  const [meetingPermissionError, setMeetingPermissionError] = useState('');
  const [loadError, setLoadError] = useState('');
  const threadRef = useRef(null);
  const activeConversation = conversations.find((item) => item.id === activeId) || null;
  const sourceIds = useMemo(() => {
    const ids = (activeConversation?.messages || [])
      .filter((message) => message.role === 'assistant')
      .flatMap((message) => message.sourceIds || []);
    return [...new Set(ids)];
  }, [activeConversation]);
  const visibleSources = useMemo(() => sourceIds.map((id) => sourceMap[id]).filter(Boolean), [sourceIds, sourceMap]);
  const userInitials = initialsFor(currentUser);
  const projectName = 'Accessible workspace';
  const canUseMeetingAgent = meetingPermissions.includes('Meetings.UseAgent');

  // Do not send transcript data to older assistant APIs that silently ignore the meeting contract.
  // Normal chat remains available even when the optional Meeting AI contract is not deployed.
  useEffect(() => {
    let alive = true;
    getMeetingPermissions()
      .then((result) => {
        if (!alive) return;
        setMeetingPermissions(Array.isArray(result?.permissions) ? result.permissions : []);
        setMeetingPermissionError('');
      })
      .catch((error) => {
        if (!alive) return;
        setMeetingPermissions([]);
        setMeetingPermissionError(error?.status === 403
          ? 'Your role does not have Meetings.UseAgent.'
          : 'The Meeting AI API is not available. Transcript context is disabled until the backend contract is enabled.');
      })
      .finally(() => { if (alive) setMeetingPermissionLoading(false); });
    return () => { alive = false; };
  }, []);

  const refreshHistory = async () => {
    const raw = await listConversations();
    const mapped = unwrapItems(raw, ['conversations']).map(mapConversation).filter((item) => item.id);
    setConversations((current) => {
      const drafts = current.filter((item) => item.isDraft);
      const byId = new Map(current.filter((item) => !item.isDraft).map((item) => [item.id, item]));
      return [...mapped.map((item) => ({ ...item, messages: byId.get(item.id)?.messages || [] })), ...drafts];
    });
    return mapped;
  };

  useEffect(() => {
    let alive = true;
    setLoadingHistory(true);
    listConversations()
      .then((raw) => {
        if (!alive) return;
        const mapped = unwrapItems(raw, ['conversations']).map(mapConversation).filter((item) => item.id);
        setConversations(mapped);
        if (mapped.length) setActiveId(mapped[0].id);
      })
      .catch((error) => { if (alive) setLoadError(errorText(error)); })
      .finally(() => { if (alive) setLoadingHistory(false); });
    return () => { alive = false; };
  }, []);

  useEffect(() => {
    if (!activeId || activeConversation?.isDraft) {
      setLoadingMessages(false);
      return undefined;
    }
    let alive = true;
    let pollTimer = null;
    setLoadingMessages(true);
    setContextOpen(false);

    const loadMessages = async (attempt = 0) => {
      try {
        const raw = await getConversationMessages(activeId);
        if (!alive) return;
        const mapped = mapServerMessages(raw);
        setSourceMap((current) => ({ ...current, ...mapped.sourceMap }));
        setConversations((current) => current.map((item) => item.id === activeId ? { ...item, messages: mapped.messages } : item));
        if (attempt === 0) setLoadError('');
        const stillProcessing = mapped.messages.some((message) => message.role === 'assistant' && message.status === 'pending');
        if (stillProcessing && attempt < 36) pollTimer = window.setTimeout(() => loadMessages(attempt + 1), 2500);
      } catch (error) {
        if (alive && attempt === 0) setLoadError(errorText(error));
        if (alive && attempt < 36) pollTimer = window.setTimeout(() => loadMessages(attempt + 1), 3500);
      } finally {
        if (alive && attempt === 0) setLoadingMessages(false);
      }
    };

    loadMessages();
    return () => { alive = false; if (pollTimer) window.clearTimeout(pollTimer); };
  }, [activeId]);

  useEffect(() => {
    const root = threadRef.current;
    if (!root) return;
    root.scrollTo({ top: root.scrollHeight, behavior: 'smooth' });
  }, [activeId, activeConversation?.messages?.length, sending]);

  useEffect(() => {
    const handleKeyDown = (event) => {
      if (event.key === 'Escape') { setContextOpen(false); setHistoryOpen(false); }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  useEffect(() => {
    if (!visibleSources.some((source) => source.id === selectedSourceId)) setSelectedSourceId(visibleSources[0]?.id || '');
  }, [visibleSources, selectedSourceId]);

  const selectConversation = (id) => {
    setMeetingTranscript(''); setMeetingMode(false);
    setActiveId(id);
    setHistoryOpen(false);
    setContextOpen(false);
    setLoadError('');
  };

  const createConversation = () => {
    setMeetingTranscript(''); setMeetingMode(false);
    const draft = newDraft();
    setConversations((items) => [draft, ...items]);
    setActiveId(draft.id);
    setContextOpen(false);
    setHistoryOpen(false);
    setLoadError('');
  };

  const sendMessage = async (text) => {
    const question = text.trim();
    if (!question || sending) return;
    const transcriptPart = meetingMode ? meetingTranscript.trim() : '';
    if (transcriptPart && !canUseMeetingAgent) {
      setLoadError(meetingPermissionError || 'Your role does not have Meetings.UseAgent. The transcript was not sent.');
      return;
    }

    let conversation = activeConversation;
    if (!conversation || !conversation.isDraft) {
      if (!conversation) {
        conversation = newDraft();
        setConversations((items) => [conversation, ...items]);
        setActiveId(conversation.id);
      }
    }

    const tempId = `pending-${uuid()}`;
    const clientMessageId = uuid();
    const userMessage = { id: `question-${tempId}`, role: 'user', text: question, time: 'Just now' };
    const pendingMessage = { id: tempId, role: 'assistant', kind: 'pending', text: 'Investigating the records available to your account…', sourceIds: [] };
    const draftId = conversation.id;
    setConversations((items) => items.map((item) => item.id === draftId ? {
      ...item,
      title: item.isDraft ? (question.length > 48 ? `${question.slice(0, 45)}…` : question) : item.title,
      updated: 'Just now',
      messages: [...(item.messages || []), userMessage, pendingMessage],
    } : item));
    setSending(true);
    setLoadError('');
    setContextOpen(false);

    try {
      const rawResult = await askAssistant({
        question,
        conversationId: conversation.isDraft ? undefined : conversation.id,
        clientMessageId,
        transcript: transcriptPart || null,
        meetingDate: transcriptPart ? meetingDate : null,
      });
      const result = unwrapPayload(rawResult);
      const nestedConversation = read(result, 'conversation', 'Conversation');
      const serverId = read(result, 'conversationId', 'ConversationId') || read(nestedConversation, 'conversationId', 'ConversationId') || read(nestedConversation, 'id', 'Id');
      if (!serverId) throw new Error('The assistant response did not include a saved conversation ID. The answer could not be attached to chat history.');
      const messageId = read(result, 'messageId', 'MessageId') || read(result, 'id', 'Id') || tempId;
      const links = mapLinks(read(result, 'links', 'Links') || read(result, 'sources', 'Sources'), messageId);
      const answer = read(result, 'answer', 'Answer') || read(result, 'response', 'Response') || read(result, 'content', 'Content') || 'The assistant returned an empty answer.';
      const status = String(read(result, 'status', 'Status') || 'answered').toLowerCase();
      const meeting = read(result, 'meeting', 'Meeting') || null;
      const choices = read(result, 'choices', 'Choices') || read(meeting, 'choices', 'Choices') || [];
      const assistantMessage = {
        id: messageId,
        role: 'assistant',
        kind: status === 'pending' ? 'pending' : status === 'failed' ? 'error' : 'backend',
        text: status === 'pending' ? (answer === 'The assistant returned an empty answer.' ? 'The assistant is still processing this request…' : answer) : answer,
        status,
        sourceIds: links.map((source) => source.id),
        choices: Array.isArray(choices) ? choices : [],
        meeting,
      };
      setSourceMap((current) => ({ ...current, ...Object.fromEntries(links.map((source) => [source.id, source])) }));
      setConversations((items) => {
        const existing = items.find((item) => item.id === serverId);
        const target = existing || items.find((item) => item.id === draftId);
        const updated = {
          ...(target || conversation),
          id: serverId || draftId,
          isDraft: false,
          title: target?.title || question.slice(0, 48),
          group: 'Today',
          updated: 'Just now',
          messages: (target?.messages || []).filter((message) => message.id !== tempId).map((message) => message),
        };
        const withoutOld = items.filter((item) => item.id !== draftId && item.id !== serverId);
        const baseMessages = (target?.messages || []).filter((message) => message.id !== tempId);
        // Keep the optimistic user question and replace only the temporary assistant bubble.
        updated.messages = [...baseMessages, assistantMessage];
        return [updated, ...withoutOld];
      });
      if (serverId) setActiveId(serverId);
      setSelectedSourceId(links[0]?.id || '');
      if (transcriptPart) setMeetingTranscript('');
      try { await refreshHistory(); } catch { /* The completed turn remains visible even if history refresh fails. */ }
    } catch (error) {
      const message = errorText(error);
      setLoadError(message);
      setConversations((items) => items.map((item) => item.id === draftId ? {
        ...item,
        messages: [...(item.messages || []).filter((entry) => entry.id !== tempId), { ...pendingMessage, kind: 'error', text: message }],
      } : item));
    } finally { setSending(false); }
  };

  const retryCurrentLoad = async () => {
    setLoadError('');
    if (!activeId || activeConversation?.isDraft) {
      try { await refreshHistory(); } catch (error) { setLoadError(errorText(error)); }
      return;
    }
    setLoadingMessages(true);
    try {
      const raw = await getConversationMessages(activeId);
      const mapped = mapServerMessages(raw);
      setSourceMap((current) => ({ ...current, ...mapped.sourceMap }));
      setConversations((current) => current.map((item) => item.id === activeId ? { ...item, messages: mapped.messages } : item));
    } catch (error) { setLoadError(errorText(error)); }
    finally { setLoadingMessages(false); }
  };

  const openSource = (id) => {
    setSelectedSourceId(id);
    setContextOpen(true);
  };

  return (
    <section className={`st-chat-page ${contextOpen ? 'st-chat-page--context-open' : ''} ${historyOpen ? 'st-chat-page--history-open' : ''}`} aria-label="SynTrace AI Assistant">
      <ChatSidebar
        conversations={conversations}
        activeId={activeId}
        search={historySearch}
        setSearch={setHistorySearch}
        onSelect={selectConversation}
        onNew={createConversation}
        onClose={() => setHistoryOpen(false)}
      />

      <main className="st-chat-main">
        <ChatHeader
          title={activeConversation?.title || 'New conversation'}
          project={projectName}
          sourceCount={visibleSources.length}
          onToggleSources={() => setContextOpen((open) => !open)}
          sourcesOpen={contextOpen}
          onToggleHistory={() => setHistoryOpen((open) => !open)}
          onNew={createConversation}
        />

        <div className="st-chat-main__body" ref={threadRef}>
          {loadError && !activeConversation?.messages?.length && (
            <div className="st-chat-load-error" role="alert"><ChatIcon name="info" size={16}/><span>{loadError}</span><button type="button" onClick={retryCurrentLoad}>Retry</button></div>
          )}
          {loadingHistory || loadingMessages ? (
            <div className="st-chat-loading"><span className="st-chat-loading__spinner"/><span>{loadingMessages ? 'Loading conversation…' : 'Loading your conversations…'}</span></div>
          ) : activeConversation?.messages?.length ? (
            <MessageThread messages={activeConversation.messages} sourceMap={sourceMap} onSourceSelect={openSource} onChoice={sendMessage} userInitials={userInitials}/>
          ) : (
            <div className="st-chat-welcome">
              <div className="st-chat-welcome__orb"><span><SynTraceMark size={38}/></span></div>
              <span className="st-chat-welcome__eyebrow">SYNTRACE INTELLIGENCE</span>
              <h2>See the context<br/><em>behind the work.</em></h2>
              <p>Ask about the projects and knowledge records you are authorized to access. Answers are generated from your company-scoped workspace.</p>
              <div className="st-chat-suggestions" aria-label="Suggested questions">
                {suggestedPrompts.map((item) => (
                  <button type="button" className="st-chat-suggestion" key={item.title} onClick={() => sendMessage(item.prompt)} disabled={sending}>
                    <span className="st-chat-suggestion__icon"><ChatIcon name={item.icon} size={16}/></span>
                    <span><strong>{item.title}</strong><small>{item.prompt}</small></span>
                    <ChatIcon name="arrow" size={15}/>
                  </button>
                ))}
              </div>
              <div className="st-chat-welcome__note"><span className="st-chat-status-dot"/> Connected to your authenticated workspace</div>
            </div>
          )}
        </div>

        <div className="st-chat-main__composer">
          <div className={`st-chat-meeting-context ${meetingMode ? 'is-open' : ''}`}>
            <button type="button" className="st-chat-meeting-toggle" onClick={() => setMeetingMode((value) => !value)} aria-expanded={meetingMode} disabled={meetingPermissionLoading || !canUseMeetingAgent} title={!canUseMeetingAgent ? (meetingPermissionError || 'Meeting AI is unavailable for this account.') : 'Attach incremental meeting transcript context'}>
              <ChatIcon name="calendar" size={14}/><span>{meetingPermissionLoading ? 'Checking meeting access…' : meetingMode ? 'Meeting context attached' : 'Add live meeting context'}</span><b>{meetingMode ? '−' : '+'}</b>
            </button>
            {!meetingPermissionLoading && !canUseMeetingAgent && <small className="st-chat-meeting-unavailable" role="status">{meetingPermissionError || 'Your role needs Meetings.UseAgent. No transcript will be sent from this chat.'}</small>}
            {meetingMode && canUseMeetingAgent && <div className="st-chat-meeting-fields">
              <label>Meeting date<input type="date" value={meetingDate} onChange={(event) => setMeetingDate(event.target.value)}/></label>
              <label className="st-chat-meeting-transcript">New transcript segment only<textarea rows={3} maxLength={400000} value={meetingTranscript} onChange={(event) => setMeetingTranscript(event.target.value)} placeholder="Paste only the new transcript lines since your last message. The same chat keeps the selected project and meeting context."/></label>
              <small>Start by saying “This is a meeting” and name the project. If more than one project is available, the assistant will ask you to choose. Send each new transcript segment once; the backend retains context for this chat.</small>
              <div className="st-chat-meeting-actions">
                <button type="button" onClick={() => sendMessage('Review this new meeting transcript segment. Identify missing details, contradictions, risks and questions to ask the client.')} disabled={sending || !meetingTranscript.trim()}>Send transcript segment</button>
                <button type="button" onClick={() => sendMessage('The meeting is finished. Please wrap it up, submit the transcript for review, and list any questions to carry into the next meeting.')} disabled={sending || !meetingTranscript.trim()} title={!meetingTranscript.trim() ? 'Add the meeting transcript before finishing.' : 'Finish the meeting and submit the current transcript.'}>Finish meeting</button>
              </div>
            </div>}
          </div>
          <ChatComposer onSend={sendMessage} disabled={sending} scope={projectName}/>
          <div className="st-chat-service-note"><span className="st-chat-status-dot"/> Company-scoped context <i/> Answers use the access granted by your backend role</div>
        </div>
      </main>

      {contextOpen && <button type="button" className="st-chat-context-scrim" aria-label="Close source details" onClick={() => setContextOpen(false)}/>}
      {contextOpen && <ContextPanel sources={visibleSources} activeSourceId={selectedSourceId} onSelectSource={setSelectedSourceId} onClose={() => setContextOpen(false)} project={projectName}/>}
      {historyOpen && <button type="button" className="st-chat-mobile-scrim" aria-label="Close conversation history" onClick={() => setHistoryOpen(false)}/>}
    </section>
  );
}
