import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  assistLiveMeeting, createAIMeeting, deleteAIMeeting, deleteLiveMeeting,
  downloadAIMeetingPdf, editProjectRequirement, endLiveMeeting, getAIMeeting,
  getAIMeetingDocument, getMeetingPermissions, getProjectOpenQuestions,
  getProjectRequirementHistory, listAIMeetings, publishMeetingDraft,
  retryAIMeeting, reviewAIMeeting, rewriteAIMeetingDocument, saveAIMeetingDocument,
  startLiveMeeting, wrapUpLiveMeeting,
} from '../../services/meetingAIService.js';
import './meeting-ai.css';

const field = (obj, ...keys) => keys.map((key) => obj?.[key]).find((value) => value !== undefined && value !== null);
const messageOf = (error, fallback) => error?.data?.detail || error?.data?.message || error?.message || fallback;
// Meeting Gateway scopes meetings by SynTrace ProjectId, not by the connected Jira project key.
const projectKeyOf = (project) => String(field(project, 'projectId', 'ProjectId', 'id', 'Id') || '').trim();
const projectNameOf = (project) => field(project, 'projectName', 'ProjectName', 'name', 'Name') || projectKeyOf(project);
const pretty = (value) => String(value || '').replace(/_/g, ' ').replace(/([a-z])([A-Z])/g, '$1 $2');
const rowsOf = (value, key) => {
  let data = value;
  for (let depth = 0; depth < 3; depth += 1) {
    const nested = data?.data ?? data?.result ?? data?.payload;
    if (!nested || nested === data) break;
    data = nested;
  }
  if (Array.isArray(data)) return data;
  const pascalKey = key ? key[0].toUpperCase() + key.slice(1) : '';
  for (const candidate of [key, pascalKey, 'items', 'Items', 'results', 'Results']) {
    if (Array.isArray(data?.[candidate])) return data[candidate];
  }
  return [];
};
const localDate = () => { const now = new Date(); return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`; };
const localDateTime = () => `${localDate()}T${String(new Date().getHours()).padStart(2, '0')}:${String(new Date().getMinutes()).padStart(2, '0')}`;
const itemKinds = [
  ['requirement', 'Requirements'], ['decision', 'Decisions'], ['action_item', 'Action items'],
  ['blocker', 'Blockers'], ['open_question', 'Open questions'],
];
const statusOptions = [
  ['all', 'All statuses'], ['processing', 'Processing'], ['pending_review', 'Pending review'],
  ['approved', 'Approved'], ['failed', 'Failed'],
];

async function hasPdfSignature(file) {
  if (!file || file.size < 5) return false;
  const header = new Uint8Array(await file.slice(0, 5).arrayBuffer());
  return String.fromCharCode(...header) === '%PDF-';
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('The selected PDF could not be read.'));
    reader.onload = () => resolve(String(reader.result || '').split(',')[1] || '');
    reader.readAsDataURL(file);
  });
}

function Stat({ value, label }) {
  return <div className="mai-stat"><strong>{value}</strong><span>{label}</span></div>;
}

function StatePill({ value }) {
  const state = String(value || 'unknown').toLowerCase();
  return <span className={`mai-status mai-status--${state.replace(/[^a-z_]/g, '')}`}>{pretty(state)}</span>;
}

function TextList({ values, empty = 'None recorded.' }) {
  if (!values?.length) return <small>{empty}</small>;
  return <ul>{values.map((value, index) => <li key={index}>{typeof value === 'string' ? value : (value?.criterion || value?.text || value?.title || JSON.stringify(value))}{value?.quote && <small> · Evidence: {value.quote}</small>}{value?.lines?.length > 0 && <small> · Lines {value.lines.join(', ')}</small>}</li>)}</ul>;
}

export default function MeetingAI({ projects = [], onBack }) {
  const projectOptions = useMemo(() => projects.map((project) => ({
    key: projectKeyOf(project), name: projectNameOf(project),
  })).filter((item) => item.key), [projects]);

  const [permissions, setPermissions] = useState(null);
  const [permissionError, setPermissionError] = useState(null);
  const [loadingPermissions, setLoadingPermissions] = useState(true);
  const [view, setView] = useState('analyze');
  const [projectKey, setProjectKey] = useState(projectOptions[0]?.key || '');
  const [sourceType, setSourceType] = useState('online');
  const [title, setTitle] = useState('');
  const [meetingDate, setMeetingDate] = useState(localDateTime());
  const [text, setText] = useState('');
  const [pdf, setPdf] = useState(null);
  const [glossary, setGlossary] = useState('');
  const [linkedSourceId, setLinkedSourceId] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [meeting, setMeeting] = useState(null);
  const [documentText, setDocumentText] = useState('');
  const [documentDirty, setDocumentDirty] = useState(false);
  const [rewritePrompt, setRewritePrompt] = useState('');
  const [rewritePart, setRewritePart] = useState('');
  const [rewriteWarnings, setRewriteWarnings] = useState([]);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [decisions, setDecisions] = useState({});
  const [draftApprovals, setDraftApprovals] = useState({});
  const [draftRemovals, setDraftRemovals] = useState({});
  const [jiraLinks, setJiraLinks] = useState({});

  const [meetingRows, setMeetingRows] = useState([]);
  const [meetingStatus, setMeetingStatus] = useState('all');
  const [loadingMeetings, setLoadingMeetings] = useState(false);
  const [historyRows, setHistoryRows] = useState([]);
  const [openQuestions, setOpenQuestions] = useState([]);
  const [historyQuery, setHistoryQuery] = useState('');
  const [loadingMemory, setLoadingMemory] = useState(false);
  const [editingRequirement, setEditingRequirement] = useState({});

  const [liveTitle, setLiveTitle] = useState('');
  const [liveSession, setLiveSession] = useState(null);
  const [liveTranscript, setLiveTranscript] = useState('');
  const [liveQuestion, setLiveQuestion] = useState('');
  const [liveSuggestions, setLiveSuggestions] = useState([]);
  const [liveAnswer, setLiveAnswer] = useState(null);
  const [wrapSuggestions, setWrapSuggestions] = useState([]);
  const [nextMeetingPrompts, setNextMeetingPrompts] = useState([]);
  const [dismissedSuggestions, setDismissedSuggestions] = useState([]);

  const pollRef = useRef(null);
  const currentProject = projectOptions.find((project) => project.key === projectKey);

  useEffect(() => {
    if (!projectKey && projectOptions[0]) setProjectKey(projectOptions[0].key);
  }, [projectKey, projectOptions]);

  useEffect(() => {
    let alive = true;
    getMeetingPermissions()
      .then((result) => { if (alive) setPermissions(Array.isArray(result?.permissions) ? result.permissions : []); })
      .catch((err) => { if (alive) setPermissionError({ message: messageOf(err, 'Meeting AI permissions could not be loaded.'), status: err?.status }); })
      .finally(() => { if (alive) setLoadingPermissions(false); });
    return () => { alive = false; };
  }, []);

  const has = useCallback((permission) => Boolean(permissions?.includes(permission)), [permissions]);
  const canCreate = has('Meetings.Create') && has('Meetings.ReadPending');
  const canReadApproved = has('Meetings.ReadApproved');
  const canReadPending = has('Meetings.ReadPending');
  const canApprove = has('Meetings.Approve') && canReadPending;
  const canEdit = has('Meetings.Edit') && canReadPending;
  const canEditRequirement = has('Meetings.Edit') && canReadApproved;
  const canRewrite = canEdit && has('Meetings.UseAgent');
  const canExport = canReadApproved && has('Meetings.ExportPdf');
  const canDelete = has('Meetings.Delete');
  const canPublish = canReadApproved && has('Meetings.PublishJiraTasks');
  const canManageLive = has('Meetings.ManageLiveSessions');
  const items = meeting?.items || [];
  const counts = useMemo(() => Object.fromEntries(itemKinds.map(([kind]) => [kind, items.filter((item) => item.type === kind).length])), [items]);

  const refreshMeeting = useCallback(async (id) => {
    const next = await getAIMeeting(id);
    setMeeting(next);
    if (next?.status === 'pending_review' || next?.status === 'approved') {
      try {
        const doc = await getAIMeetingDocument(id);
        setDocumentText(String(field(doc, 'text', 'document', 'content') || ''));
        setDocumentDirty(false);
      } catch { /* Evidence review remains available when no document can be generated. */ }
    }
    return next;
  }, []);

  useEffect(() => {
    if (!meeting?.sourceId || meeting.status !== 'processing') return undefined;
    pollRef.current = window.setInterval(() => {
      refreshMeeting(meeting.sourceId).catch((err) => setError(messageOf(err, 'Meeting status could not be refreshed.')));
    }, 3500);
    return () => window.clearInterval(pollRef.current);
  }, [meeting?.sourceId, meeting?.status, refreshMeeting]);

  const refreshMeetingList = useCallback(async () => {
    if (!projectKey) return;
    if (!canReadApproved && !canReadPending) { setMeetingRows([]); return; }
    setLoadingMeetings(true);
    try {
      const response = await listAIMeetings(projectKey, meetingStatus === 'all' ? '' : meetingStatus);
      const visible = rowsOf(response, 'meetings').filter((row) => row.status === 'approved' ? canReadApproved : canReadPending);
      setMeetingRows(visible);
    } catch (err) { setError(messageOf(err, 'Project meetings could not be loaded.')); }
    finally { setLoadingMeetings(false); }
  }, [projectKey, meetingStatus, canReadApproved, canReadPending]);

  useEffect(() => {
    if (view === 'meetings') refreshMeetingList();
  }, [view, refreshMeetingList]);

  const refreshProjectMemory = useCallback(async () => {
    if (!projectKey || !canReadApproved) return;
    setLoadingMemory(true);
    try {
      const [history, questions] = await Promise.all([
        getProjectRequirementHistory(projectKey, historyQuery), getProjectOpenQuestions(projectKey),
      ]);
      setHistoryRows(rowsOf(history, 'requirements'));
      setOpenQuestions(rowsOf(questions, 'openQuestions'));
    } catch (err) { setError(messageOf(err, 'Project memory could not be loaded.')); }
    finally { setLoadingMemory(false); }
  }, [projectKey, historyQuery, canReadApproved]);

  useEffect(() => {
    if (view === 'memory') refreshProjectMemory();
  }, [view, refreshProjectMemory]);

  const resetMeeting = () => {
    setMeeting(null); setDocumentText(''); setDocumentDirty(false); setRewritePrompt(''); setRewritePart(''); setRewriteWarnings([]); setDecisions({}); setDraftApprovals({}); setDraftRemovals({});
    setJiraLinks({}); setLinkedSourceId(''); setText(''); setPdf(null); setTitle(''); setGlossary('');
    setSourceType('online'); setMeetingDate(localDateTime());
    setNextMeetingPrompts([]); setWrapSuggestions([]);
    setError(''); setNotice('');
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError(''); setNotice('');
    if (!canCreate) return setError('Your role needs Meetings.Create and Meetings.ReadPending to submit a meeting.');
    if (!projectKey) return setError('Choose one of your accessible SynTrace projects.');
    if (sourceType === 'pdf' && !pdf) return setError('Choose a PDF file to analyze.');
    if (sourceType === 'pdf' && (pdf.size <= 0 || pdf.size > 10 * 1024 * 1024)) return setError('Choose a PDF larger than 0 bytes and smaller than 10 MB so the encoded payload stays within the Gateway limit.');
    if (sourceType !== 'pdf' && !text.trim()) return setError('Paste the transcript or meeting notes before starting analysis.');
    const terms = glossary.split(/[\n,،]/).map((part) => part.trim()).filter(Boolean);
    if (terms.length > 200 || terms.some((term) => term.length > 60)) return setError('The glossary supports up to 200 terms, each up to 60 characters.');
    setSubmitting(true);
    try {
      if (sourceType === 'pdf' && !(await hasPdfSignature(pdf))) return setError('The selected file does not have a valid PDF signature. Choose a real PDF file.');
      const payload = {
        projectKey, sourceType, title: title.trim() || null,
        meetingDate: meetingDate ? meetingDate.slice(0, 10) : null,
        text: sourceType === 'pdf' ? null : text,
        pdfBase64: sourceType === 'pdf' ? await fileToBase64(pdf) : null,
        glossary: terms, linkedSourceId: linkedSourceId || null,
      };
      const created = await createAIMeeting(payload);
      setMeeting(created); setDecisions({}); setDraftApprovals({}); setDraftRemovals({}); setJiraLinks({});
      setDocumentText(''); setDocumentDirty(false); setRewriteWarnings([]); setView('analyze');
      setNotice(linkedSourceId ? 'Correction submitted and linked to the approved meeting.' : 'Meeting submitted. SynTrace is analyzing it now.');
      if (created?.sourceId) await refreshMeeting(created.sourceId);
    } catch (err) { setError(messageOf(err, 'The meeting could not be submitted.')); }
    finally { setSubmitting(false); }
  };

  const handleReview = async () => {
    if (!meeting?.sourceId) return;
    const approveItems = Object.entries(decisions).filter(([, value]) => value === 'approve').map(([id]) => id);
    const remove = Object.entries(decisions).filter(([, value]) => value === 'delete').map(([id]) => id);
    const approveDrafts = Object.entries(draftApprovals).filter(([, value]) => value).map(([id]) => id);
    const removeDrafts = Object.entries(draftRemovals).filter(([, value]) => value).map(([id]) => id);
    const approve = [...new Set([...approveItems, ...approveDrafts])];
    const removeAll = [...new Set([...remove, ...removeDrafts])];
    const hasConfirmedLinks = Object.values(jiraLinks).some((values) => Array.isArray(values) && values.some(Boolean));
    const remainingItems = items.filter((item) => item.status !== 'approved' && !remove.includes(item.id) && !approveItems.includes(item.id));
    const finalizingSource = remainingItems.length === 0;
    const unresolvedDrafts = items.flatMap((item) => (item.drafts || []).map((draft) => ({ item, draft })))
      .filter(({ item, draft }) => !remove.includes(item.id) && !approve.includes(draft.id) && !removeDrafts.includes(draft.id) && draft.status !== 'approved' && !draft.jiraKey);
    if (finalizingSource && unresolvedDrafts.length) {
      return setError('Before approving the whole meeting, approve or decline every Jira draft. Draft approval is a separate decision.');
    }
    const finalProposalWithoutDraft = finalizingSource && items.some((item) => {
      const isProposal = item.needsReview || String(item.text || '').startsWith('Proposed:');
      const draftEligible = item.type === 'requirement' && (!item.relation || ['new', 'change'].includes(item.relation)) && item.clarity !== 'unclear';
      return isProposal && draftEligible && decisions[item.id] === 'approve' && !(item.drafts || []).length;
    });
    if (finalProposalWithoutDraft) {
      return setError('The current AI backend generates a Jira draft after accepting a proposal. It cannot review that new draft once the meeting is fully approved. Keep another item pending during proposal approval, or delete this proposal for now.');
    }
    if (!approve.length && !removeAll.length && !hasConfirmedLinks && items.length > 0) return setError('Choose an item decision, confirm a Jira link, or explicitly approve or decline a Jira draft.');
    if (!items.length && !window.confirm('The AI returned no review items. Approve this empty analysis and finish the meeting review?')) return;
    setBusy('review'); setError('');
    try {
      const links = Object.fromEntries(Object.entries(jiraLinks)
        .map(([id, values]) => [id, (Array.isArray(values) ? values : []).filter(Boolean)])
        .filter(([, values]) => values.length));
      const result = await reviewAIMeeting(meeting.sourceId, { approve, remove: removeAll, links });
      setDecisions({}); setDraftApprovals({}); setDraftRemovals({}); setJiraLinks({});
      setMeeting(result);
      setNotice(result?.status === 'approved' ? 'Meeting approved and its accepted evidence was sent to project memory.' : 'Review decisions were saved. Items not decided remain pending.');
      if (result?.sourceId) await refreshMeeting(result.sourceId);
    } catch (err) { setError(messageOf(err, 'Meeting review could not be saved.')); }
    finally { setBusy(''); }
  };

  const handleRetry = async (sourceId) => {
    setBusy(`retry:${sourceId}`); setError('');
    try {
      const result = await retryAIMeeting(sourceId);
      setMeeting(result); setDecisions({}); setDraftApprovals({}); setDraftRemovals({}); setView('analyze'); setNotice('Retry started using the meeting source already stored by the AI service.');
      await refreshMeeting(sourceId);
      setView('analyze');
    } catch (err) { setError(messageOf(err, 'This meeting could not be retried. Only failed meetings can be retried.')); }
    finally { setBusy(''); }
  };

  const handleDelete = async (sourceId) => {
    if (!window.confirm('Delete this meeting and remove its evidence from project memory?')) return;
    setBusy(`delete:${sourceId}`); setError('');
    try {
      await deleteAIMeeting(sourceId);
      setMeetingRows((current) => current.filter((row) => row.sourceId !== sourceId));
      if (meeting?.sourceId === sourceId) resetMeeting();
      setNotice('Meeting deleted. Its requirement-memory changes are replayed by the AI service.');
    } catch (err) { setError(messageOf(err, 'Meeting could not be deleted.')); }
    finally { setBusy(''); }
  };

  const handleSaveDocument = async () => {
    setBusy('save'); setError('');
    try {
      await saveAIMeetingDocument(meeting.sourceId, documentText);
      await refreshMeeting(meeting.sourceId);
      setDocumentDirty(false); setNotice('Document saved; its changed, added and removed lines were synchronized to the review items.');
    } catch (err) { setError(messageOf(err, 'Document could not be saved.')); }
    finally { setBusy(''); }
  };

  const handleRewrite = async () => {
    if (!rewritePrompt.trim() || !canRewrite) return;
    setBusy('rewrite'); setError('');
    try {
      const result = await rewriteAIMeetingDocument(meeting.sourceId, rewritePrompt.trim(), rewritePart.trim() || null);
      const proposal = field(result, 'proposal', 'text', 'document');
      if (typeof proposal !== 'string' || !proposal.trim()) throw new Error('The AI did not return a rewrite proposal. Your saved meeting document was not changed.');
      setDocumentText(proposal); setDocumentDirty(true); setRewritePrompt('');
      setRewriteWarnings(Array.isArray(result?.warnings) ? result.warnings : []);
      setNotice('AI rewrite proposal is ready for review. It is not applied to meeting items until you save it.');
    } catch (err) { setError(messageOf(err, 'AI rewrite could not be completed.')); }
    finally { setBusy(''); }
  };

  const handlePdf = async () => {
    setBusy('pdf'); setError('');
    try { await downloadAIMeetingPdf(meeting.sourceId); }
    catch (err) { setError(messageOf(err, 'PDF export is unavailable.')); }
    finally { setBusy(''); }
  };

  const openMeeting = async (sourceId) => {
    setBusy(`open:${sourceId}`); setError('');
    try { await refreshMeeting(sourceId); setDecisions({}); setDraftApprovals({}); setDraftRemovals({}); setJiraLinks({}); setRewritePrompt(''); setRewritePart(''); setRewriteWarnings([]); setView('analyze'); }
    catch (err) { setError(messageOf(err, 'Meeting details could not be loaded.')); }
    finally { setBusy(''); }
  };

  const handleSaveRequirement = async (id) => {
    const nextText = (editingRequirement[id] || '').trim();
    if (!nextText) return setError('Requirement text cannot be empty.');
    setBusy(`requirement:${id}`); setError('');
    try {
      await editProjectRequirement(id, nextText);
      setEditingRequirement((current) => { const copy = { ...current }; delete copy[id]; return copy; });
      await refreshProjectMemory(); setNotice('Requirement updated. Its edit is recorded in the lifecycle history.');
    } catch (err) { setError(messageOf(err, 'Requirement could not be updated.')); }
    finally { setBusy(''); }
  };

  const handleStartLive = async (event) => {
    event.preventDefault();
    if (!canManageLive) return setError('Your role needs Meetings.ManageLiveSessions to use the live assistant.');
    setBusy('live-start'); setError('');
    try {
      const session = await startLiveMeeting(projectKey, liveTitle.trim() || null);
      setLiveSession(session); setLiveSuggestions(session?.suggestions || []); setWrapSuggestions([]); setNextMeetingPrompts([]);
      setLiveAnswer(null); setDismissedSuggestions([]); setLiveTranscript(''); setLiveQuestion('');
      setNotice('Live assistant started. Nothing is added to project memory or Jira until the meeting is sent for review and approved.');
    } catch (err) { setError(messageOf(err, 'Live assistant could not be started.')); }
    finally { setBusy(''); }
  };

  const handleLiveAssist = async () => {
    if (!liveSession?.sessionId) return;
    if (!liveTranscript.trim() && !liveQuestion.trim()) return setError('Paste the transcript so far or ask a project question.');
    setBusy('live-assist'); setError('');
    try {
      const result = await assistLiveMeeting(liveSession.sessionId, {
        transcript: liveTranscript, question: liveQuestion.trim() || null, dismiss: dismissedSuggestions,
      });
      const known = new Set(liveSuggestions.map((suggestion) => suggestion.id));
      setLiveSuggestions((current) => [
        ...current,
        ...(result?.suggestions || []).filter((suggestion) => !known.has(suggestion.id) && !dismissedSuggestions.includes(suggestion.id)),
      ]);
      setLiveAnswer(result?.answer || null); setLiveQuestion('');
    } catch (err) { setError(messageOf(err, 'Live suggestions could not be generated.')); }
    finally { setBusy(''); }
  };

  const handleWrapUp = async () => {
    if (!liveSession?.sessionId || !liveTranscript.trim()) return setError('Paste the meeting transcript before the wrap-up check.');
    setBusy('live-wrap'); setError('');
    try {
      const result = await wrapUpLiveMeeting(liveSession.sessionId, liveTranscript);
      setWrapSuggestions(result?.suggestions || []);
      setNotice('Wrap-up check completed. Review any remaining questions before ending the meeting.');
    } catch (err) { setError(messageOf(err, 'The live meeting wrap-up could not be completed.')); }
    finally { setBusy(''); }
  };

  const handleEndLive = async (sendForReview) => {
    if (!liveSession?.sessionId) return;
    if (sendForReview && (!liveTranscript.trim() || !canCreate)) return setError('Sending a transcript requires text plus Meetings.Create and Meetings.ReadPending.');
    const confirmed = window.confirm(sendForReview
      ? 'End the live session and submit this transcript as an online meeting for review?'
      : 'End the live session without sending its transcript for review?');
    if (!confirmed) return;
    setBusy('live-end'); setError('');
    try {
      const result = await endLiveMeeting(liveSession.sessionId, {
        transcript: sendForReview ? liveTranscript : null,
        meetingDate: sendForReview ? localDate() : null,
      });
      setLiveSession(null); setLiveTranscript(''); setLiveSuggestions([]); setWrapSuggestions([]); setNextMeetingPrompts([]); setLiveAnswer(null);
      if (result?.sourceId) {
        setProjectKey(result.projectKey || projectKey);
        await refreshMeeting(result.sourceId); setView('analyze');
        setNotice('Live meeting ended. Its transcript was submitted and is waiting for the normal evidence review.');
      } else {
        setNotice('Live meeting ended. Open questions and items not asked are shown below for the next meeting.');
      }
      const nextPrompts = [
        ...(result?.nextMeeting?.notAsked || []).map((item) => ({ ...item, kind: item.kind || 'ask_client', id: item.id || `next-${item.text}` })),
        ...(result?.nextMeeting?.openQuestions || []).map((item) => ({ ...item, kind: 'open_question', id: item.id || `question-${item.text}` })),
      ];
      setWrapSuggestions(nextPrompts); setNextMeetingPrompts(nextPrompts);
    } catch (err) { setError(messageOf(err, 'The live session could not be ended.')); }
    finally { setBusy(''); }
  };

  const handleDeleteLive = async () => {
    if (!liveSession?.sessionId || !window.confirm('Delete this live session? Its transcript will not be submitted.')) return;
    setBusy('live-delete'); setError('');
    try {
      await deleteLiveMeeting(liveSession.sessionId); setLiveSession(null); setLiveTranscript('');
      setLiveSuggestions([]); setWrapSuggestions([]); setNextMeetingPrompts([]); setNotice('Live session deleted.');
    } catch (err) { setError(messageOf(err, 'Live session could not be deleted.')); }
    finally { setBusy(''); }
  };

  const handlePublishDraft = async (draft) => {
    if (!meeting?.sourceId || !canPublish) return;
    const owningItem = items.find((item) => (item.drafts || []).some((entry) => entry.id === draft.id));
    if (draft.stale || owningItem?.needsReview || draft.status !== 'approved' || meeting.status !== 'approved') {
      return setError('This Jira draft is not safe to publish. The meeting, requirement and draft must all be approved, and the draft must be current.');
    }
    if (!window.confirm(`Create the Jira issue “${draft.title}” from this approved draft?`)) return;
    setBusy(`publish:${draft.id}`); setError('');
    try {
      const result = await publishMeetingDraft(meeting.sourceId, draft.id);
      const made = result.subtaskKeys?.length || 0;
      const failed = result.failedSubtasks?.length || 0;
      setNotice(`Jira issue ${result.jiraKey} was created${made ? ` with ${made} subtasks` : ''}${failed ? `; ${failed} subtasks could not be created` : ''}.`);
      await refreshMeeting(meeting.sourceId);
    } catch (err) { setError(messageOf(err, 'The Jira draft could not be published.')); }
    finally { setBusy(''); }
  };

  const dismissLiveSuggestion = (id) => {
    setDismissedSuggestions((current) => [...new Set([...current, id])]);
    setLiveSuggestions((current) => current.filter((suggestion) => suggestion.id !== id));
  };

  const goToCorrection = (row) => {
    if (!canCreate) return setError('Correction requires Meetings.Create and Meetings.ReadPending.');
    resetMeeting(); setSourceType('note'); setLinkedSourceId(row.sourceId); setProjectKey(row.projectKey || projectKey);
    setTitle(`Correction: ${row.title || 'Meeting'}`); setView('analyze');
    setNotice('This new source will be linked to the approved meeting. It will not overwrite the original.');
  };

  return (
    <main className="mai-page st-view-enter">
      <header className="mai-heading">
        <div>
          <div className="mai-breadcrumb"><button type="button" onClick={onBack}>Workspace</button><span>/</span><strong>Meeting AI</strong></div>
          <span className="st-eyebrow">MEETING INTELLIGENCE</span>
          <h1>Meeting AI</h1>
          <p>Evidence-backed requirements, a traceable project memory and live meeting guidance.</p>
        </div>
        <div className="mai-heading-actions">
          <span className="mai-live-mark"><i/> AI WORKFLOW</span>
          <button type="button" className="mai-secondary" onClick={() => { resetMeeting(); setView('analyze'); }}>New analysis</button>
        </div>
      </header>

      {permissionError && <div className="mai-alert mai-alert--warning"><strong>{permissionError.status === 404 || permissionError.status === 503 ? 'Meeting API is not deployed or enabled yet.' : permissionError.status === 403 ? 'Meeting permissions could not be read for this account.' : 'Could not connect to the Meeting API.'}</strong><span>{permissionError.message}</span><small>The authenticated /api/meetings contract must be deployed and enabled in the backend.</small></div>}
      {error && <div className="mai-alert mai-alert--error" role="alert">{error}</div>}
      {notice && <div className="mai-alert mai-alert--success" role="status">{notice}</div>}

      <nav className="mai-nav" aria-label="Meeting AI sections">
        {[
          ['analyze', 'Analyze meeting'], ['meetings', 'Project meetings'],
          ['memory', 'Project memory'], ['live', 'Live assistant'],
        ].map(([id, label]) => <button key={id} type="button" className={view === id ? 'is-active' : ''} onClick={() => { setView(id); setError(''); }}>{label}</button>)}
        <label className="mai-project-switch">Project
          <select value={projectKey} disabled={Boolean(liveSession)} onChange={(event) => { const nextProject = event.target.value; resetMeeting(); setHistoryRows([]); setOpenQuestions([]); setMeetingRows([]); setProjectKey(nextProject); }}>
            {projectOptions.map((project) => <option key={project.key} value={project.key}>{project.name}</option>)}
          </select>
        </label>
      </nav>

      {view === 'analyze' && <>
        <section className="mai-stats">
          <Stat value={items.length || '—'} label="Extracted items"/>
          <Stat value={counts.requirement || 0} label="Requirements"/>
          <Stat value={counts.action_item || 0} label="Action items"/>
          <Stat value={meeting?.rejectedItems ?? '—'} label="Evidence rejected"/>
        </section>
        <div className="mai-layout">
          <section className="mai-main-card">
            {!meeting ? <>
              <div className="mai-card-heading"><div><span className="mai-step">01 / INPUT</span><h2>{linkedSourceId ? 'Add a meeting correction' : 'Start with a meeting'}</h2><p>{linkedSourceId ? 'This correction is a new source linked to an approved meeting. The original record stays intact.' : 'Submit a transcript, written notes or a text-based PDF. Access is checked against your selected SynTrace project.'}</p></div><span className="mai-orb">✳</span></div>
              {linkedSourceId && <div className="mai-link-banner">Linked to approved meeting <code>{linkedSourceId}</code><button type="button" onClick={() => setLinkedSourceId('')}>Remove link</button></div>}
              <form className="mai-form" onSubmit={handleSubmit}>
                <div className="mai-source-tabs" role="group" aria-label="Meeting source type">
                  {[['online','Online meeting'],['offline','Offline meeting'],['note','Written notes'],['pdf','PDF document']].map(([value, label]) => <button key={value} type="button" className={sourceType === value ? 'is-active' : ''} onClick={() => setSourceType(value)}>{label}</button>)}
                </div>
                <div className="mai-form-grid">
                  <label>SynTrace project (internal project ID)
                    <select value={projectKey} onChange={(event) => setProjectKey(event.target.value)} required>
                      <option value="">Choose a project</option>
                      {projectOptions.map((project) => <option key={project.key} value={project.key}>{project.name}</option>)}
                    </select>
                  </label>
                  <label>Meeting date<input type="datetime-local" value={meetingDate} onChange={(event) => setMeetingDate(event.target.value)}/></label>
                  <label className="mai-full">Meeting title<input value={title} onChange={(event) => setTitle(event.target.value)} maxLength={300} placeholder="e.g. Checkout flow requirements review"/></label>
                  {sourceType === 'pdf' ? <label className="mai-full mai-file-drop"><input type="file" accept="application/pdf,.pdf" onChange={(event) => setPdf(event.target.files?.[0] || null)}/><span className="mai-file-icon">↥</span><strong>{pdf?.name || 'Choose a PDF file'}</strong><small>Text-based PDF · up to 10 MB source size</small></label> : <label className="mai-full">Transcript or meeting notes<textarea rows={11} value={text} onChange={(event) => setText(event.target.value)} maxLength={400000} placeholder="Paste the transcript or notes here. Arabic and English can be mixed…"/></label>}
                  <label className="mai-full">Project glossary <small className="mai-inline-hint">Optional · up to 200 terms, comma or line separated</small><input value={glossary} onChange={(event) => setGlossary(event.target.value)} placeholder="Product names, acronyms, client terminology…"/></label>
                </div>
                {!projectOptions.length && <p className="mai-inline-warning">No accessible SynTrace ProjectId values were returned for this account. Ask an administrator to assign you to a project.</p>}
                {loadingPermissions && <p className="mai-inline-hint">Checking meeting permissions…</p>}
                {permissions && !canCreate && <p className="mai-inline-warning">Your role needs both Meetings.Create and Meetings.ReadPending to submit a meeting.</p>}
                <div className="mai-form-footer"><span><i/> Company and project permissions are enforced by the backend.</span><button className="mai-primary" type="submit" disabled={submitting || loadingPermissions || !canCreate || !projectKey}>{submitting ? 'Submitting…' : linkedSourceId ? 'Submit correction' : 'Analyze meeting'} <b>→</b></button></div>
              </form>
            </> : <>
              <div className="mai-card-heading"><div><span className="mai-step">02 / ANALYSIS</span><h2>{meeting.title || 'Meeting analysis'}</h2><p>{currentProject?.name || meeting.projectKey} · {meeting.meetingDate ? new Date(meeting.meetingDate).toLocaleString() : 'Date not supplied'}</p><small className="mai-source-id">Source ID: {meeting.sourceId}{meeting.linkedSourceId ? ` · Correction of ${meeting.linkedSourceId}` : ''}</small></div><StatePill value={meeting.status}/></div>
              {nextMeetingPrompts.length > 0 && <section className="mai-wrap-up"><strong>Carry forward to the next meeting</strong><div className="mai-live-suggestions">{nextMeetingPrompts.map((prompt) => <article key={prompt.id}><StatePill value={prompt.kind}/><p>{prompt.text}</p></article>)}</div></section>}
          {meeting.status === 'processing' && <div className="mai-processing"><span className="mai-spinner"/><div><strong>Analyzing the conversation</strong><p>Extracting requirements, decisions, risks and evidence. This view refreshes automatically.</p></div></div>}
              {meeting.status === 'failed' && <div className="mai-inline-warning">{meeting.error || meeting.analysisError || 'Analysis failed.'}{canCreate ? ' Use Retry to process the stored source again.' : ' Check the service and ask an administrator for retry permission.'}<button type="button" className="mai-secondary" onClick={() => handleRetry(meeting.sourceId)} disabled={!canCreate || busy === `retry:${meeting.sourceId}`}>{busy === `retry:${meeting.sourceId}` ? 'Retrying…' : 'Retry same meeting'}</button></div>}
              {meeting.analysisError && <div className="mai-alert mai-alert--warning"><strong>Analysis note</strong><span>{meeting.analysisError}</span></div>}
              {meeting.rejectedItems > 0 && <div className="mai-alert mai-alert--warning"><strong>{meeting.rejectedItems} item(s) rejected by evidence validation.</strong><span>The AI service did not find the supplied quote in the source transcript, so those items were not added to review.</span></div>}
              {meeting.unresolvedReferences?.length > 0 && <div className="mai-alert mai-alert--warning"><strong>Unresolved references</strong><span>{meeting.unresolvedReferences.join(' · ')}</span></div>}
              {meeting.summary && <section className="mai-summary"><span>AI SUMMARY</span><p>{meeting.summary}</p></section>}
              {meeting.notes && <section className="mai-summary"><span>MEETING NOTES</span><p>{meeting.notes}</p></section>}
              {meeting.runInfo && <details className="mai-run-info"><summary>AI processing details</summary>
                {meeting.runInfo.models && <div><strong>Model routing</strong><TextList values={Object.entries(meeting.runInfo.models).map(([step, model]) => `${pretty(step)}: ${model || 'not reported'}`)}/></div>}
                {meeting.runInfo.seconds && <div><strong>Processing time</strong><TextList values={Object.entries(meeting.runInfo.seconds).map(([step, seconds]) => `${pretty(step)}: ${seconds}s`)}/></div>}
                {meeting.runInfo.prompts && <div><strong>Prompt versions</strong><TextList values={Object.entries(meeting.runInfo.prompts).map(([step, version]) => `${pretty(step)}: ${version}`)}/></div>}
                {meeting.runInfo.extractRoute && <small>Extraction route: {meeting.runInfo.extractRoute}</small>}
                {meeting.runInfo.extractFallback && <small>Extraction fallback: {meeting.runInfo.extractFallback}</small>}
              </details>}

              <div className="mai-item-heading"><div><span className="mai-step">EXTRACTED FROM SOURCE</span><h3>Evidence review</h3></div><span>{items.length} items</span></div>
              {items.length ? <div className="mai-items">{items.map((item) => {
                const isProposal = Boolean(item.needsReview || String(item.text || '').startsWith('Proposed:'));
                return <article className={`mai-item ${isProposal ? 'mai-item--proposal' : ''}`} key={item.id}>
                  <div className="mai-item-top"><span className={`mai-kind mai-kind--${item.type}`}>{pretty(item.type)}</span><span className="mai-item-state">{pretty(item.status)}{isProposal ? ' · Proposal to review' : ''}</span></div>
                  <h4>{item.text}</h4>
                  {item.userStory && <p className="mai-user-story">{item.userStory}</p>}
                  {item.evidence && <blockquote>{item.evidence}{item.evidenceLines?.length > 0 && <small> · Lines {item.evidenceLines.join(', ')}</small>}</blockquote>}
                  <div className="mai-item-meta">
                    {item.speaker && <span>Speaker · {item.speaker}</span>}{item.owner && <span>Owner · {item.owner}</span>}{item.due && <span>Due · {item.due}</span>}
                    {item.priority && <span>Priority · {pretty(item.priority)}</span>}{item.category && <span>Scope · {pretty(item.category)}</span>}{item.clarity && <span>Clarity · {pretty(item.clarity)}</span>}
                    {item.relation && <span>Relation · {pretty(item.relation)}</span>}
                  </div>
                  {item.relationNote && <p className="mai-question">Context: {item.relationNote}</p>}
                  {item.relatedKeys?.length > 0 && <p className="mai-question">Related project tickets: {item.relatedKeys.join(' · ')}</p>}
                  {item.acceptanceSaid?.length > 0 && <div className="mai-criteria"><strong>Acceptance criteria mentioned in the meeting</strong><TextList values={item.acceptanceSaid}/></div>}
                  {item.acceptanceSuggested?.length > 0 && <div className="mai-criteria mai-criteria--suggested"><strong>AI-suggested criteria · not agreed by the client</strong><TextList values={item.acceptanceSuggested}/></div>}
                  {item.priorityQuote && <p className="mai-question">Priority evidence: “{item.priorityQuote}”</p>}
                  {item.clarifyingQuestion && <p className="mai-question">Clarification needed: {item.clarifyingQuestion}</p>}
                  {item.suggestedLinks?.length > 0 && <div className="mai-suggestions mai-suggestions--select"><strong>Suggested Jira links · select only links you have verified</strong><div>{item.suggestedLinks.map((link) => { const key = typeof link === 'string' ? link : (link.key || link.jiraKey); return key ? <label key={key}><input type="checkbox" checked={(jiraLinks[item.id] || []).includes(key)} onChange={(event) => setJiraLinks((current) => ({ ...current, [item.id]: event.target.checked ? [...new Set([...(current[item.id] || []), key])] : (current[item.id] || []).filter((value) => value !== key) }))}/>{key}</label> : null; })}</div></div>}
                  {item.jiraLinks?.length > 0 && <div className="mai-suggestions"><strong>Confirmed Jira links</strong><span>{item.jiraLinks.map((link) => link.key || link).join(' · ')}</span></div>}
                  {item.answeredBy?.length > 0 && <div className="mai-history-links"><strong>Answered by a later meeting</strong>{item.answeredBy.map((entry) => <div key={entry.id}><b>{entry.title || 'Meeting'} · {entry.meetingDate || ''}</b><p>{entry.text}</p></div>)}</div>}
                  {item.relatedEarlier?.length > 0 && <div className="mai-history-links"><strong>Related earlier meeting evidence</strong>{item.relatedEarlier.map((entry) => <div key={entry.id}><b>{entry.title || pretty(entry.type)} · {entry.meetingDate || ''}</b><p>{entry.text}</p></div>)}</div>}
                  {item.drafts?.length > 0 && <div className="mai-drafts"><strong>Jira drafts · separate approval required</strong>{item.drafts.map((draft) => <section key={draft.id}>
                    <div><b>{draft.title}</b><StatePill value={draft.status || 'pending'}/></div>
                    {draft.description && <p>{draft.description}</p>}
                    {draft.acceptance?.length > 0 && <div><small>Acceptance criteria</small><TextList values={draft.acceptance}/></div>}
                    {draft.subtasks?.length > 0 && <div><small>Suggested subtasks</small><TextList values={draft.subtasks.map((subtask) => typeof subtask === 'string' ? subtask : [subtask.title, subtask.tag, subtask.assignee || subtask.suggestedAssignee, subtask.storyPoints != null ? `${subtask.storyPoints} points` : '', subtask.estimateHours != null ? `${subtask.estimateHours} hours` : ''].filter(Boolean).join(' · '))}/></div>}
                    {draft.estimateBasedOn?.length > 0 && <div><small>Estimate based on similar Jira tickets</small><TextList values={draft.estimateBasedOn}/></div>}
                    <div className="mai-draft-meta">{draft.storyPoints != null && <small>{draft.storyPoints} story points</small>}{draft.estimateHours != null && <small>{draft.estimateHours} hours</small>}{draft.jiraLabel && <small>Link label: {draft.jiraLabel}</small>}{draft.stale && <small>Draft needs refresh after document edits</small>}</div>
                    {meeting.status === 'pending_review' && canApprove && draft.status !== 'approved' && <div className="mai-draft-review-controls"><label className="mai-draft-approve"><input type="checkbox" checked={Boolean(draftApprovals[draft.id])} disabled={Boolean(draftRemovals[draft.id])} onChange={(event) => setDraftApprovals((current) => ({ ...current, [draft.id]: event.target.checked }))}/> Approve this Jira draft separately</label><label className="mai-draft-decline"><input type="checkbox" checked={Boolean(draftRemovals[draft.id])} disabled={Boolean(draftApprovals[draft.id])} onChange={(event) => setDraftRemovals((current) => ({ ...current, [draft.id]: event.target.checked }))}/> Decline this draft (keep the requirement)</label></div>}
                    {draft.jiraKey && <p className="mai-published">Published as {draft.jiraKey}</p>}
                    {!draft.jiraKey && meeting.status === 'approved' && draft.status === 'approved' && !draft.stale && !item.needsReview && canPublish && <button type="button" className="mai-secondary mai-publish" onClick={() => handlePublishDraft(draft)} disabled={busy === `publish:${draft.id}`}>{busy === `publish:${draft.id}` ? 'Publishing…' : 'Publish approved draft to Jira'}</button>}
                    {!draft.jiraKey && draft.stale && <small className="mai-draft-wait">This draft is stale after a document edit and cannot be published safely. Regenerate or review it in the backend before publishing.</small>}
                    {!draft.jiraKey && !draft.stale && (draft.status !== 'approved' || item.needsReview) && <small className="mai-draft-wait">Publish is unavailable until this item and draft are approved.</small>}
                  </section>)}</div>}
                  {meeting.status === 'pending_review' && canApprove && <div className="mai-review-controls">
                    <select aria-label={`Review ${item.text}`} value={decisions[item.id] || ''} onChange={(event) => setDecisions((current) => ({ ...current, [item.id]: event.target.value }))}>
                      <option value="">Choose item decision</option><option value="approve">Approve item</option><option value="delete">Delete item</option>
                    </select>
                    <small className="mai-review-hint">Choose a suggestion above to confirm a Jira link. Unlisted keys cannot be linked from this review.</small>
                  </div>}
                </article>;
              })}</div> : meeting.status !== 'processing' && <div className="mai-empty-items">No extracted items were returned for this meeting. Review the source details and analysis note before approving.</div>}
              {meeting.scope && <div className="mai-scope-grid">{[['Agreed', meeting.scope.agreed], ['Out of scope', meeting.scope.outOfScope], ['Open', meeting.scope.open]].map(([label, values]) => <div key={label}><strong>{label}</strong><TextList values={(values || []).map((id) => items.find((item) => item.id === id)?.text || id)} empty="None detected."/></div>)}</div>}
              {meeting.status === 'pending_review' && canEdit && <section className="mai-document">
                <div className="mai-item-heading"><div><span className="mai-step">REVIEW DOCUMENT</span><h3>Meeting document</h3></div><span>{documentDirty ? 'Unsaved changes' : 'Saved'}</span></div>
                <textarea rows={9} maxLength={40000} value={documentText} onChange={(event) => { setDocumentText(event.target.value); setDocumentDirty(true); }}/>
                {canRewrite && <div className="mai-rewrite-block"><label>What should the AI change?<input value={rewritePrompt} onChange={(event) => setRewritePrompt(event.target.value)} maxLength={500} placeholder="Ask AI to clarify, reorganize or rewrite…"/></label><label>Section or passage to target <small className="mai-inline-hint">Optional · leave blank to rewrite the whole document</small><textarea rows={2} maxLength={8000} value={rewritePart} onChange={(event) => setRewritePart(event.target.value)} placeholder="Paste a heading or exact passage to focus the rewrite…"/></label><button type="button" onClick={handleRewrite} disabled={busy === 'rewrite' || !rewritePrompt.trim()}>{busy === 'rewrite' ? 'Rewriting…' : 'Suggest rewrite'}</button></div>}
                {rewriteWarnings.length > 0 && <div className="mai-alert mai-alert--warning"><strong>Check these AI-generated details</strong><TextList values={rewriteWarnings} empty="No warnings."/></div>}
                <div className="mai-doc-actions"><button type="button" className="mai-secondary" onClick={handleSaveDocument} disabled={busy === 'save' || !documentDirty}>{busy === 'save' ? 'Saving…' : 'Save document and synchronize items'}</button></div>
              </section>}
              <footer className="mai-analysis-footer">
                <button type="button" className="mai-secondary" onClick={resetMeeting}>Start another meeting</button>
                {meeting.status === 'pending_review' && canApprove && <button type="button" className="mai-primary" onClick={handleReview} disabled={busy === 'review'}>{busy === 'review' ? 'Saving review…' : items.length ? 'Submit selected review decisions' : 'Approve empty analysis'} <b>→</b></button>}
                {meeting.status === 'approved' && canExport && <button type="button" className="mai-primary" onClick={handlePdf} disabled={busy === 'pdf'}>{busy === 'pdf' ? 'Preparing PDF…' : 'Export approved requirements PDF'} <b>↓</b></button>}
              </footer>
            </>}
          </section>

          <aside className="mai-side-card">
            <div className="mai-side-head"><span className="mai-side-icon">✳</span><div><strong>Meeting AI controls</strong><small>Permission-aware workflow</small></div></div>
            <div className="mai-capability-list">
              {[
                ['01', 'Evidence review', 'Every accepted item is reviewed before memory indexing', canApprove ? 'Available' : 'Restricted'],
                ['02', 'Project memory', 'Approved requirement history and unanswered questions', canReadApproved ? 'Available' : 'Restricted'],
                ['03', 'Live assistance', 'Transcript increments, reminders, conflicts and wrap-up', canManageLive ? 'Available' : 'Restricted'],
                ['04', 'Jira publishing', 'Only separately approved drafts can create Jira issues', canPublish ? 'Available' : 'Restricted'],
              ].map(([number, label, detail, status]) => <div key={number}><span>{number}</span><section><strong>{label}</strong><small>{detail}</small><em className={status === 'Restricted' ? 'is-pending' : ''}>{status}</em></section></div>)}
            </div>
            <div className="mai-side-note"><strong>Approval gates are intentional</strong><p>Suggested requirements, proposed items and suggested acceptance criteria are not client agreements. Project memory updates only after meeting approval. Jira issues are created only when an authorized user publishes an approved draft.</p></div>
            <div className="mai-side-foot"><span className="mai-lock">⌑</span><span>Backend re-checks tenant, project and role permissions on every operation.</span></div>
          </aside>
        </div>
      </>}

      {view === 'meetings' && <section className="mai-main-card mai-secondary-view">
        <div className="mai-card-heading"><div><span className="mai-step">PROJECT RECORDS</span><h2>Meetings in this project</h2><p>Browse processing state, review progress, and approved meetings. The list does not return transcripts.</p></div><button type="button" className="mai-secondary" onClick={refreshMeetingList} disabled={loadingMeetings}>{loadingMeetings ? 'Refreshing…' : 'Refresh list'}</button></div>
        <div className="mai-list-toolbar"><label>Status<select value={meetingStatus} onChange={(event) => setMeetingStatus(event.target.value)}>{statusOptions.filter(([value]) => value !== 'processing' || canReadPending).filter(([value]) => value !== 'pending_review' || canReadPending).filter(([value]) => value !== 'failed' || canReadPending).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label><span>{meetingRows.length} meetings</span></div>
        {!canReadApproved && !canReadPending ? <div className="mai-empty-items">Your role does not have Meetings.ReadApproved or Meetings.ReadPending.</div> : loadingMeetings ? <div className="mai-processing"><span className="mai-spinner"/><strong>Loading project meetings…</strong></div> : meetingRows.length ? <div className="mai-meeting-list">{meetingRows.map((row) => <article key={row.sourceId}>
          <div className="mai-meeting-row-main"><div><strong>{row.title || `${pretty(row.sourceType)} meeting`}</strong><small>{row.meetingDate || 'Date not supplied'} · {row.sourceType} · {row.sourceId}</small></div><StatePill value={row.status}/></div>
          <div className="mai-meeting-row-meta"><span>{row.items ?? 0} extracted items</span><span>{row.toReview ?? 0} require review</span>{row.linkedSourceId && <span>Correction of {row.linkedSourceId}</span>}</div>
          {row.error && <p className="mai-question">{row.error}</p>}
          <div className="mai-meeting-row-actions"><button type="button" className="mai-secondary" onClick={() => openMeeting(row.sourceId)} disabled={busy === `open:${row.sourceId}`}>{busy === `open:${row.sourceId}` ? 'Opening…' : 'Open details'}</button>
            {row.status === 'failed' && canCreate && <button type="button" className="mai-secondary" onClick={() => handleRetry(row.sourceId)} disabled={busy === `retry:${row.sourceId}`}>Retry</button>}
            {row.status === 'approved' && canCreate && canReadApproved && <button type="button" className="mai-secondary" onClick={() => goToCorrection(row)}>Add correction</button>}
            {has('Meetings.Delete') && (row.status === 'approved' ? canReadApproved : canReadPending) && <button type="button" className="mai-danger" onClick={() => handleDelete(row.sourceId)} disabled={busy === `delete:${row.sourceId}`}>Delete</button>}
          </div>
        </article>)}</div> : <div className="mai-empty-items">No meetings found for this project and status.</div>}
      </section>}

      {view === 'memory' && <section className="mai-main-card mai-secondary-view">
        <div className="mai-card-heading"><div><span className="mai-step">APPROVED KNOWLEDGE</span><h2>Project memory</h2><p>Requirement lifecycle across approved meetings, including clarifications, edits, drops and restorations.</p></div><button type="button" className="mai-secondary" onClick={refreshProjectMemory} disabled={loadingMemory || !canReadApproved}>{loadingMemory ? 'Refreshing…' : 'Refresh memory'}</button></div>
        {!canReadApproved ? <div className="mai-empty-items">This section requires Meetings.ReadApproved.</div> : <>
          <section className="mai-memory-section"><div className="mai-item-heading"><div><span className="mai-step">REQUIREMENTS</span><h3>Requirement history</h3></div><span>{historyRows.length} records</span></div>
            <div className="mai-memory-search"><input value={historyQuery} onChange={(event) => setHistoryQuery(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter') refreshProjectMemory(); }} placeholder="Search requirement text or lifecycle history…"/><button type="button" className="mai-secondary" onClick={refreshProjectMemory} disabled={loadingMemory}>Search</button></div>
            {historyRows.length ? <div className="mai-requirement-list">{historyRows.map((requirement) => <article key={requirement.id}>
              <div className="mai-meeting-row-main"><StatePill value={requirement.status}/><small>Updated {requirement.updatedAt || 'date unavailable'}</small></div>
              <textarea rows={2} maxLength={400} value={editingRequirement[requirement.id] ?? requirement.text} onChange={(event) => setEditingRequirement((current) => ({ ...current, [requirement.id]: event.target.value }))} disabled={!canEditRequirement}/>
              {canEditRequirement && <div className="mai-meeting-row-actions"><button type="button" className="mai-secondary" onClick={() => handleSaveRequirement(requirement.id)} disabled={busy === `requirement:${requirement.id}` || (editingRequirement[requirement.id] ?? requirement.text) === requirement.text}>{busy === `requirement:${requirement.id}` ? 'Saving…' : 'Save requirement edit'}</button></div>}
              {requirement.changes?.length > 0 && <div className="mai-change-list"><strong>Lifecycle</strong>{requirement.changes.map((change, index) => <div key={`${change.at || index}-${index}`}><span>{pretty(change.type)} · {change.meeting || (change.by ? `Edited by ${change.by}` : 'Project history')}</span><small>{change.meetingDate || change.at || ''}</small>{change.before && <p>Before: {change.before}</p>}{change.after && <p>After: {change.after}</p>}{change.quote && <blockquote>{change.quote}{change.lines?.length ? ` · Lines ${change.lines.join(', ')}` : ''}</blockquote>}{change.note && <small>{change.note}</small>}</div>)}</div>}
            </article>)}</div> : <div className="mai-empty-items">No approved requirement history was found for this project.</div>}
          </section>
          <section className="mai-memory-section"><div className="mai-item-heading"><div><span className="mai-step">OPEN QUESTIONS</span><h3>Questions still awaiting an answer</h3></div><span>{openQuestions.length}</span></div>
            {openQuestions.length ? <div className="mai-open-question-list">{openQuestions.map((question) => <article key={question.id}><strong>{question.text}</strong>{question.quote && <blockquote>{question.quote}</blockquote>}<small>{question.meeting || 'Earlier meeting'} · {question.meetingDate || 'Date not supplied'}</small></article>)}</div> : <div className="mai-empty-items">No unanswered questions from approved meetings.</div>}
          </section>
        </>}
      </section>}

      {view === 'live' && <section className="mai-main-card mai-secondary-view">
        <div className="mai-card-heading"><div><span className="mai-step">LIVE MEETING SUPPORT</span><h2>Live meeting assistant</h2><p>Paste the transcript as it grows. The AI reads new lines, checks project context and suggests questions, missing details, conflicts and risks.</p></div><span className="mai-live-mark"><i/> LIVE</span></div>
        {!canManageLive ? <div className="mai-empty-items">This section requires Meetings.ManageLiveSessions. Starting or continuing a session is checked by the backend.</div> : !liveSession ? <form className="mai-form mai-live-start" onSubmit={handleStartLive}>
          <div className="mai-form-grid"><label className="mai-full">Meeting title<input value={liveTitle} onChange={(event) => setLiveTitle(event.target.value)} maxLength={300} placeholder="Optional meeting title"/></label></div>
          <button type="submit" className="mai-primary" disabled={busy === 'live-start' || !projectKey}>{busy === 'live-start' ? 'Starting…' : 'Start live assistant'} <b>→</b></button>
        </form> : <>
          <div className="mai-live-session-head"><div><strong>{liveSession.title || 'Live meeting session'}</strong><small>{liveSession.projectKey || currentProject?.name || projectKey} · {liveSession.sessionId}</small></div><StatePill value={liveSession.status || 'live'}/></div>
          <label className="mai-live-transcript">Transcript so far<textarea rows={12} maxLength={400000} value={liveTranscript} onChange={(event) => setLiveTranscript(event.target.value)} placeholder="Paste the transcript from the beginning. On each request, only new lines are analyzed…"/></label>
          <div className="mai-live-question"><input value={liveQuestion} onChange={(event) => setLiveQuestion(event.target.value)} maxLength={400} placeholder="Ask about what the client said or earlier project requirements…"/><button type="button" className="mai-primary" onClick={handleLiveAssist} disabled={busy === 'live-assist'}>{busy === 'live-assist' ? 'Checking…' : 'Get live help'}</button></div>
          {liveAnswer?.text && <div className="mai-live-answer"><strong>Answer from the meeting and project context</strong><p>{liveAnswer.text}</p>{liveAnswer.quote && <blockquote>{liveAnswer.quote}{liveAnswer.lines?.length ? ` · Lines ${liveAnswer.lines.join(', ')}` : ''}</blockquote>}</div>}
          <div className="mai-live-actions"><button type="button" className="mai-secondary" onClick={handleWrapUp} disabled={busy === 'live-wrap' || !liveTranscript.trim()}>{busy === 'live-wrap' ? 'Checking wrap-up…' : 'Check before ending'}</button><button type="button" className="mai-secondary" onClick={() => handleEndLive(false)} disabled={busy === 'live-end'}>End without submitting transcript</button>{canCreate && <button type="button" className="mai-primary" onClick={() => handleEndLive(true)} disabled={busy === 'live-end' || !liveTranscript.trim()}>{busy === 'live-end' ? 'Ending…' : 'End and send for review'}</button>}<button type="button" className="mai-danger" onClick={handleDeleteLive} disabled={busy === 'live-delete'}>Delete session</button></div>
          <div className="mai-item-heading"><div><span className="mai-step">NEW SIGNALS</span><h3>Suggestions and risks</h3></div><span>{liveSuggestions.length}</span></div>
          {liveSuggestions.length ? <div className="mai-live-suggestions">{liveSuggestions.map((suggestion) => <article key={suggestion.id}><div><StatePill value={suggestion.kind}/><button type="button" className="mai-text-button" onClick={() => dismissLiveSuggestion(suggestion.id)}>Mark asked / not needed</button></div><strong>{suggestion.text}</strong>{suggestion.quote && <blockquote>{suggestion.quote}{suggestion.lines?.length ? ` · Lines ${suggestion.lines.join(', ')}` : ''}</blockquote>}{suggestion.ref && <small>Related project context: {suggestion.ref.where || suggestion.ref.text}</small>}</article>)}</div> : <div className="mai-empty-items">No suggestions yet. Paste the transcript and select Get live help.</div>}
          {wrapSuggestions.length > 0 && <section className="mai-wrap-up"><strong>Wrap-up / next meeting</strong><div className="mai-live-suggestions">{wrapSuggestions.map((suggestion) => <article key={suggestion.id}><StatePill value={suggestion.kind}/><p>{suggestion.text}</p>{suggestion.quote && <blockquote>{suggestion.quote}</blockquote>}</article>)}</div></section>}
          <p className="mai-live-safety">Live suggestions are advisory. They do not write to project memory or Jira. Ending with transcript submits a new online meeting for the standard evidence review.</p>
        </>}
        {!liveSession && nextMeetingPrompts.length > 0 && <section className="mai-wrap-up"><strong>Carry forward to the next meeting</strong><div className="mai-live-suggestions">{nextMeetingPrompts.map((prompt) => <article key={prompt.id}><StatePill value={prompt.kind}/><p>{prompt.text}</p>{prompt.quote && <blockquote>{prompt.quote}</blockquote>}</article>)}</div></section>}
      </section>}
    </main>
  );
}
