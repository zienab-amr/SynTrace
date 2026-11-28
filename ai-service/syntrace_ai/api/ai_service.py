"""
ai_service.py
HTTP service the backend calls for user questions. It must not be exposed to the internet.

  uvicorn ai_service:app --host 0.0.0.0 --port 8000

Tenant and allowed projects come from the backend, which takes them from the user's JWT.
Question and answer text are never logged, except that setting UNANSWERED_LOG_PATH writes
unanswered questions to that private file, so they can be reviewed. It is off by default.
"""
import hashlib
import json
import re
import logging
import os
import secrets
import threading
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Annotated, Dict, List, Literal, Optional, Union

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Query, Response
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

load_dotenv()

from syntrace_ai.assistant import cache_version
from syntrace_ai.assistant import cancel
from syntrace_ai.assistant import conversation
from syntrace_ai.assistant import names
from syntrace_ai.assistant.answer_generator import _is_arabic, generate_answer_result
from syntrace_ai.graph.query_engine import AccessContext, run_query

log = logging.getLogger("syntrace.service")


def _resume_meetings():
    try:
        from syntrace_ai.meetings import meeting_notes
        resumed = meeting_notes.resume_processing()
        if resumed:
            log.info("resumed %d meeting sources left processing", resumed)
    except Exception as exc:   # Neo4j not up yet: the sources resume on the next start
        log.warning("could not resume meeting processing: %s", type(exc).__name__)


@asynccontextmanager
async def _lifespan(_app):
    threading.Thread(target=_resume_meetings, daemon=True).start()
    yield


app = FastAPI(title="SynTrace AI", docs_url=None, redoc_url=None, openapi_url=None, lifespan=_lifespan)


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class AskRequest(CamelModel):
    question: str = Field(min_length=1, max_length=2000)
    company_id: str = Field(min_length=1, max_length=200)
    employee_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    # SynTrace project ids the backend allows (AiService:EnableSynTraceProjectScope): the only scope for
    # approved knowledge sources. Without them no knowledge source is searched.
    allowed_syntrace_project_ids: List[str] = Field(default_factory=list, max_length=5000,
                                                   alias="allowedSynTraceProjectIds")  # the backend's casing
    jira_account_id: Optional[str] = Field(default=None, max_length=200)
    # One chat in the app. Follow-up questions are read in the context of the same chat only.
    conversation_id: Optional[str] = Field(default=None, max_length=200)
    # The chat's last questions and answers, oldest first, when the backend keeps the chat history.
    # When the field is sent, even as [], it is the whole context: the service's own short memory is not
    # used (it could belong to another chat after a restart or a load balancer move).
    history: List["Turn"] = Field(default_factory=list, max_length=conversation.KEPT_TURNS * 2)
    # The user edited an earlier question: how many of the chat's last questions to forget first,
    # counting the edited one. Only needed while the backend does not send history.
    edited_turns: int = Field(default=0, ge=0, le=50)
    # Messages the user sent before this one that have no answer yet, oldest first. They are answered
    # together with this one; the backend cancels their own requests with DELETE /ask/{correlationId}.
    added_to: List[str] = Field(default_factory=list, max_length=5)
    # Parts of earlier messages the user selected and replied to (Reply in the app), oldest first. Only
    # context for understanding the question: they come from the app, so they prove nothing about access;
    # what may be read is still decided by the company and projects above.
    quoted_excerpts: List[Annotated[str, Field(max_length=2000)]] = Field(default_factory=list, max_length=5)
    # A part of a meeting transcript the user pasted in the chat (the meeting is going on): it gets live
    # help for the project the chat named. Sent apart from the question, which stays short.
    transcript: Optional[str] = Field(default=None, max_length=400_000)
    meeting_date: Optional[str] = Field(default=None, max_length=40)
    # What this user may do with meetings, by the company's own permissions (the backend decides; no
    # role is hard-coded here). Anything not sent is not allowed.
    permissions: "Permissions" = Field(default_factory=lambda: Permissions())


class Permissions(CamelModel):
    can_read_approved_meetings: bool = False   # answers may use approved meetings
    can_use_meeting_agent: bool = False        # meeting help from the chat (live help, wrap-up, end)
    can_approve_meeting: bool = False          # the backend checks it on review; sent for completeness
    can_publish_jira_tasks: bool = False       # the backend checks it when it creates tickets


class Turn(CamelModel):
    question: str = Field(max_length=2000)
    answer: str = Field(default="", max_length=8000)


AskRequest.model_rebuild()


class Link(CamelModel):
    key: str
    url: str


class AskResponse(CamelModel):
    status: str
    answer: str
    links: List[Link]
    correlation_id: str
    source: Optional[str] = None
    # When the assistant asked one question back (source "clarify"): up to four short answers the app can
    # show as buttons; tapping one sends its text as the next question in the same chat. Otherwise empty.
    choices: List[str] = Field(default_factory=list)


class AskMeetingResponse(AskResponse):
    # Only when the message was about a meeting in this chat: {sessionId, project, suggestions, ...} or
    # {needsProject: true, choices: [...]} when the agent asked which project. Other answers keep the
    # usual contract.
    meeting: Optional[Dict] = None


CACHE_SECONDS = int(os.getenv("ASK_CACHE_SECONDS", "3600"))
# Stop calling the model after this many seconds, so an answer comes back before the backend's own
# timeout (AiService:TimeoutSeconds) cuts the request. Keep it a few seconds below that timeout.
ASK_DEADLINE = float(os.getenv("ASK_DEADLINE_SECONDS", "75"))
TIME_UP_AR = "السؤال ده محتاج وقت أطول من المسموح. جرب تحدده أكتر، زي اسم المشروع أو الـ sprint أو رقم التذكرة."
TIME_UP_EN = "This question needs more time than allowed. Try narrowing it, for example with a project, sprint or ticket key."
CACHE_SIZE = 500
# Identical questions in one scope. The key holds the company's cache token, which the consumer
# changes on every Jira change, so a saved answer never outlives the data it was built from.
_answers = {}


def _cached_answer(question, ctx):
    if CACHE_SECONDS <= 0:
        return generate_answer_result(question, ctx)
    version = cache_version.token(ctx.tenant_id, run_query)
    if version is None:   # Neo4j can't say whether data changed, so don't trust saved answers
        return generate_answer_result(question, ctx)
    # Today's date is in the key because "overdue" and "this week" change at midnight.
    key = (ctx.tenant_id, version, datetime.now(timezone.utc).date(), ctx.allowed_projects, ctx.syntrace_projects,
           ctx.jira_account_id, ctx.can_read_meetings,
           " ".join(question.lower().split()))
    now = time.monotonic()
    cached = _answers.get(key)
    if cached and now - cached[0] < CACHE_SECONDS:
        return cached[1]
    result = generate_answer_result(question, ctx)
    cancel.check()   # a cancelled request's answer is not saved
    if result["status"] == "ok":
        if len(_answers) >= CACHE_SIZE:
            _answers.pop(next(iter(_answers)))
        _answers[key] = (now, result)
    return result


UNANSWERED = {"no_results", "not_found", "clarify", "search_unavailable"}


def _record_unanswered(question, company_id, status, correlation):
    """A write failure must never fail the answer."""
    path = os.getenv("UNANSWERED_LOG_PATH")
    if not path or status not in UNANSWERED:
        return
    entry = {"at": datetime.now(timezone.utc).isoformat(), "status": status, "correlation": correlation,
             "company": hashlib.sha256(company_id.encode()).hexdigest()[:12], "question": question}
    try:
        with open(path, "a", encoding="utf-8") as out:
            out.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError as exc:
        log.warning("could not record an unanswered question: %s", type(exc).__name__)


def _authorize(key):
    expected = os.getenv("AI_API_KEY")
    if not expected:   # never run open because of a missing setting
        raise HTTPException(503, "AI_API_KEY is not configured")
    if not key or not secrets.compare_digest(key.encode(), expected.encode()):
        raise HTTPException(401, "invalid API key")


@app.post("/ask", response_model=Union[AskMeetingResponse, AskResponse], response_model_by_alias=True)
def ask(request: AskRequest, x_internal_api_key: Optional[str] = Header(default=None),
        x_correlation_id: Optional[str] = Header(default=None)):
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    question = request.question.strip()
    if not question:
        raise HTTPException(400, "question is empty")
    ctx = AccessContext(request.company_id, tuple(p.strip().upper() for p in request.allowed_projects if p.strip()),
                        request.jira_account_id,
                        tuple(sorted({p.strip() for p in request.allowed_syntrace_project_ids if p.strip()})),
                        can_read_meetings=request.permissions.can_read_approved_meetings)
    history_sent = "history" in request.model_fields_set
    if history_sent:
        turns = conversation.from_history([(t.question, t.answer) for t in request.history])
    else:
        conversation.drop_last(request.company_id, request.employee_id, request.conversation_id,
                               request.edited_turns)
        turns = conversation.recent(request.company_id, request.employee_id, request.conversation_id)
    from syntrace_ai.assistant import timing
    timer = timing.begin()
    started = cancel.start(correlation, ASK_DEADLINE)
    try:
        cancel.check()   # cancelled before it started
        meeting = _chat_meeting(request, ctx, question)
        if meeting is not None:
            log.info("ask correlation=%s meeting", correlation)
            timing.end(timer)
            cancel.check()
            info = meeting.get("meeting") or {}
            return AskMeetingResponse(status=meeting["status"], answer=meeting["answer"], links=[],
                                      correlation_id=correlation, source="meeting", meeting=info,
                                      choices=[str(c.get("name") if isinstance(c, dict) else c)
                                               for c in info.get("choices") or []][:4]
                                      if info.get("needsProject") else [])
        if request.quoted_excerpts:   # what the user replied to is the newest context
            turns = turns + conversation.quoted(request.quoted_excerpts)
        if request.added_to:
            asked = conversation.merge([m[:2000] for m in request.added_to] + [question], turns)
        else:
            asked = conversation.standalone(question, turns)
        result = _cached_answer(asked, ctx)
        cancel.check()   # cancelled while answering: this answer must not be returned or remembered
    except cancel.TimeUp:
        result = {"status": "no_results", "answer": TIME_UP_AR if _is_arabic(question) else TIME_UP_EN,
                  "links": [], "source": "timeout"}
    except cancel.Cancelled:
        log.info("cancelled correlation=%s %s", correlation, timing.summary())
        timing.end(timer)
        raise HTTPException(409, "cancelled") from None
    except Exception as exc:
        log.error("ask failed correlation=%s error=%s %s", correlation, timing.error_label(exc), timing.summary())
        timing.end(timer)
        raise HTTPException(503, "assistant is unavailable") from None
    finally:
        cancel.finish(started)
    log.info("ask correlation=%s status=%s source=%s %s", correlation, result["status"], result.get("source"),
             timing.summary())
    timing.end(timer)
    try:
        result["answer"] = names.latinize(result["answer"], names.people(ctx))
    except Exception as exc:   # a name list problem must never fail the answer
        log.warning("name check failed: %s", type(exc).__name__)
    if result["status"] == "ok" and not history_sent:
        conversation.remember(request.company_id, request.employee_id, request.conversation_id,
                              asked, result["answer"], result["links"])
    _record_unanswered(question, request.company_id, result["status"], correlation)
    if result["status"] == "search_unavailable":
        log.error("search unavailable correlation=%s", correlation)
        raise HTTPException(503, "assistant is unavailable")
    return AskResponse(status=result["status"], answer=result["answer"], links=result["links"],
                       correlation_id=correlation,
                       source=result.get("source") or ("ticket" if result["status"] == "ok" else None),
                       choices=result.get("choices") or [])


def _chat_meeting(request, ctx, question):
    """Live meeting help when the chat is about a meeting going on, else None (the usual answer)."""
    if not request.conversation_id:
        return None
    if not request.permissions.can_use_meeting_agent:
        if request.transcript:   # a pasted meeting the user may not use: say so instead of answering on it
            return {"status": "ok", "meeting": None,
                    "answer": "مساعدة الـ meetings مش متاحة لحسابك. اسأل الأدمن في شركتك." if _is_arabic(question)
                    else "Meeting help is not available to your account. Ask your company's admin."}
        return None
    from syntrace_ai.meetings import meeting_notes
    try:
        return meeting_notes.chat_meetings().handle(meeting_notes.meeting_ctx(ctx), request.employee_id,
                                                    request.conversation_id, question, request.transcript,
                                                    request.meeting_date)
    except meeting_notes.MeetingError as exc:
        log.warning("chat meeting failed: %s", exc)
        return {"status": "ok", "answer": "مش قادر أساعد في الـ meeting دلوقتي، جرّب تاني." if _is_arabic(question)
                else "I can't help with the meeting right now; try again.", "meeting": None}
    except Exception as exc:   # the meeting store is down: the chat still answers the question
        log.warning("chat meeting unavailable: %s", type(exc).__name__)
        if request.transcript:
            return {"status": "ok", "answer": "مش قادر أقرا الـ meeting دلوقتي، ابعته تاني بعد شوية." if _is_arabic(question)
                    else "I can't read the meeting right now; send it again in a moment.", "meeting": None}
        return None


# ---------- Meeting notes ----------
# The backend decides who may submit and review, by each company's policy, and sends the company and projects from
# the JWT. This service checks that the source's project is one of them.

class MeetingRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    source_id: str = Field(min_length=1, max_length=200, pattern=r"^[A-Za-z0-9_.:-]+$")
    project_key: str = Field(min_length=1, max_length=100)
    source_type: Literal["online", "offline", "note", "pdf"]
    title: Optional[str] = Field(default=None, max_length=300)
    meeting_date: Optional[str] = Field(default=None, max_length=40)
    text: Optional[str] = Field(default=None, max_length=400_000)
    pdf_base64: Optional[str] = Field(default=None, max_length=14_000_000)
    created_by: Optional[str] = Field(default=None, max_length=200)
    linked_source_id: Optional[str] = Field(default=None, max_length=200)
    glossary: List[str] = Field(default_factory=list, max_length=200)   # words the team adds


class ReviewRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    reviewer_id: str = Field(min_length=1, max_length=200)
    approve: List[str] = Field(default_factory=list, max_length=500)
    delete: List[str] = Field(default_factory=list, max_length=500)
    links: Dict[str, List[str]] = Field(default_factory=dict, max_length=500)   # item id -> confirmed suggested keys


class ScopeRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)


def _meeting_ctx(company_id, projects):
    return AccessContext(company_id, tuple(p.strip().upper() for p in projects if p.strip()))


def _meeting_call(work, correlation):
    from syntrace_ai.meetings import meeting_notes
    try:
        return work(meeting_notes)
    except meeting_notes.MeetingError as exc:
        if exc.status >= 500:
            log.error("meeting call failed correlation=%s error=%s", correlation, exc)
        raise HTTPException(exc.status, str(exc)) from None
    except HTTPException:
        raise
    except Exception as exc:
        log.error("meeting call failed correlation=%s error=%s", correlation, type(exc).__name__)
        raise HTTPException(503, "meeting notes are unavailable") from None


def _meeting_response(result, correlation):
    """camelCase for the backend."""
    source, items = result["source"], result["items"]
    body = {
        "sourceId": source["source_id"], "sourceType": source["source_type"], "title": source["title"],
        "meetingDate": source["meeting_date"], "projectKey": source["project_key"], "status": source["status"],
        "linkedSourceId": source.get("linked_source_id"), "error": source.get("error"),
        "unresolvedReferences": source.get("unresolved_keys") or [],
        "rejectedItems": source.get("rejected_items") or 0,
        "summary": source.get("summary"), "notes": source.get("notes"),
        "analysisError": source.get("analysis_error"), "runInfo": source.get("run_info") or {},
        "scope": {"agreed": (source.get("scope") or {}).get("agreed") or [],
                  "outOfScope": (source.get("scope") or {}).get("out_of_scope") or [],
                  "open": (source.get("scope") or {}).get("open") or []},
        "items": [{"id": i["uid"], "type": i["type"], "text": i["text"], "evidence": i["evidence"],
                   "evidenceLines": i.get("lines") or [],
                   "owner": i["owner"], "due": i["due"], "needsReview": i["needs_review"], "status": i["status"],
                   "jiraLinks": i["links"], "suggestedLinks": i.get("suggested") or [],
                   "speaker": i.get("speaker"), "relation": i.get("relation"),
                   "relatedKeys": i.get("related_keys") or [], "relationNote": i.get("relation_note"),
                   "userStory": i.get("user_story"), "category": i.get("category"), "clarity": i.get("clarity"),
                   "clarifyingQuestion": i.get("clarify_question"), "priority": i.get("priority"),
                   "priorityQuote": i.get("priority_quote"), "acceptanceSaid": i.get("acceptance_said") or [],
                   "acceptanceSuggested": i.get("acceptance_suggested") or [],
                   "answeredBy": [{"id": a["uid"], "text": a["text"], "meetingDate": a["date"], "title": a["title"]}
                                  for a in i.get("answered_by") or []],
                   "relatedEarlier": [{"id": e["uid"], "type": e["type"], "text": e["text"], "meetingDate": e["date"],
                                       "title": e["title"]} for e in i.get("earlier") or []],
                   "drafts": [{"id": d["uid"], "title": d["title"], "description": d.get("description"),
                               "acceptance": d.get("acceptance") or [], "subtasks": d.get("subtasks") or [],
                               "storyPoints": d.get("story_points"), "estimateHours": d.get("estimate_hours"),
                               "estimateBasedOn": d.get("estimate_based_on") or [], "status": d.get("status"),
                               "stale": bool(d.get("stale")),
                               # SYNT-920: the label to put on the Jira ticket made from this draft; the ticket
                               # comes back through the webhook linked to it (status "published", jiraKey)
                               "jiraLabel": d.get("jira_label"), "jiraKey": d.get("jira_key")}
                              for d in i.get("drafts") or []]} for i in items],
        "correlationId": correlation,
    }
    if "indexed" in result:
        body["indexed"] = result["indexed"]
    return body


@app.post("/meetings", status_code=202)
def create_meeting(request: MeetingRequest, x_internal_api_key: Optional[str] = Header(default=None),
                   x_correlation_id: Optional[str] = Header(default=None)):
    """Accept a transcript, notes or PDF and extract its items in the background. The reply comes at once
    with status `processing`; GET /meetings/{id} shows `pending_review` (or `failed` with an error) when
    it is done. Sending the same sourceId again restarts it, until it is approved."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    result = _meeting_call(lambda m: m.submit_source(
        ctx, request.source_id, request.project_key, request.source_type, request.title, request.meeting_date,
        request.text, request.pdf_base64, request.created_by, request.linked_source_id,
        glossary=request.glossary), correlation)
    return _meeting_response(result, correlation)


@app.get("/meetings/{source_id}")
def get_meeting(source_id: str, company_id: str = Query(alias="companyId", min_length=1),
                allowed_projects: str = Query(alias="allowedProjects", default=""),
                x_internal_api_key: Optional[str] = Header(default=None),
                x_correlation_id: Optional[str] = Header(default=None)):
    """allowedProjects is a comma-separated list."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    return _meeting_response(_meeting_call(lambda m: m.get_source(ctx, source_id), correlation), correlation)


@app.post("/meetings/{source_id}/review")
def review_meeting(source_id: str, request: ReviewRequest, x_internal_api_key: Optional[str] = Header(default=None),
                   x_correlation_id: Optional[str] = Header(default=None)):
    """Approve or delete items, and confirm suggested tickets with `links`. When no item is left pending,
    the source is approved and searchable, without the text of the deleted items."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    result = _meeting_call(lambda m: m.review_source(ctx, source_id, request.approve, request.delete,
                                                     request.reviewer_id, request.links), correlation)
    _answers.clear()   # cached answers must not hide newly approved meetings
    return _meeting_response(result, correlation)


@app.post("/meetings/{source_id}/retry", status_code=202)
def retry_meeting(source_id: str, request: ScopeRequest, x_internal_api_key: Optional[str] = Header(default=None),
                  x_correlation_id: Optional[str] = Header(default=None)):
    """Read a failed meeting again from the text it was sent with (409 when it did not fail)."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    return _meeting_response(_meeting_call(lambda m: m.retry_source(ctx, source_id), correlation), correlation)


@app.get("/projects/{project_key}/meetings")
def list_meetings(project_key: str, company_id: str = Query(alias="companyId", min_length=1),
                  allowed_projects: str = Query(alias="allowedProjects", default=""),
                  status: Optional[str] = Query(default=None, max_length=20),
                  x_internal_api_key: Optional[str] = Header(default=None),
                  x_correlation_id: Optional[str] = Header(default=None)):
    """The project's meetings, newest first, without their text or items (`status` narrows the list)."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    found = _meeting_call(lambda m: m.list_sources(ctx, project_key, status or None), correlation)
    return {"meetings": [{"sourceId": s["source_id"], "sourceType": s["source_type"], "title": s.get("title"),
                          "meetingDate": s.get("meeting_date"), "status": s["status"], "projectKey": s["project_key"],
                          "error": s.get("error"), "linkedSourceId": s.get("linked_source_id"),
                          "createdAt": s.get("created_at"), "createdBy": s.get("created_by"),
                          "items": s["items"], "toReview": s["to_review"]} for s in found],
            "correlationId": correlation}


@app.delete("/meetings/{source_id}", status_code=204)
def delete_meeting(source_id: str, company_id: str = Query(alias="companyId", min_length=1),
                   allowed_projects: str = Query(alias="allowedProjects", default=""),
                   x_internal_api_key: Optional[str] = Header(default=None),
                   x_correlation_id: Optional[str] = Header(default=None)):
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    _meeting_call(lambda m: m.delete_source(ctx, source_id), correlation)
    _answers.clear()
    return Response(status_code=204)


# ---------- The notes as a text the user edits, and the requirements PDF ----------

class DocumentRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    text: str = Field(min_length=1, max_length=40_000)
    edited_by: Optional[str] = Field(default=None, max_length=200)


class RewriteRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    instruction: str = Field(min_length=1, max_length=500)
    part: Optional[str] = Field(default=None, max_length=8000)   # the selected lines; empty: all the notes


@app.get("/meetings/{source_id}/document")
def get_meeting_document(source_id: str, company_id: str = Query(alias="companyId", min_length=1),
                         allowed_projects: str = Query(alias="allowedProjects", default=""),
                         x_internal_api_key: Optional[str] = Header(default=None),
                         x_correlation_id: Optional[str] = Header(default=None)):
    """The meeting notes as the text the user reads, edits and copies."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    return dict(_meeting_call(lambda m: m.document(ctx, source_id), correlation), correlationId=correlation)


@app.put("/meetings/{source_id}/document")
def save_meeting_document(source_id: str, request: DocumentRequest, x_internal_api_key: Optional[str] = Header(default=None),
                          x_correlation_id: Optional[str] = Header(default=None)):
    """Save the edited notes: the edits go back to the items (changed, added by the user, removed)."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    result = _meeting_call(lambda m: m.edit_document(ctx, source_id, request.text, request.edited_by), correlation)
    response = _meeting_response(result, correlation)
    response["changes"] = result.get("changes")
    return response


@app.post("/meetings/{source_id}/document/rewrite")
def rewrite_meeting_document(source_id: str, request: RewriteRequest,
                             x_internal_api_key: Optional[str] = Header(default=None),
                             x_correlation_id: Optional[str] = Header(default=None)):
    """The agent's proposal for an edit the user asked for; nothing is saved until the user saves it."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    result = _meeting_call(lambda m: m.rewrite_document(ctx, source_id, request.instruction, request.part), correlation)
    return dict(result, correlationId=correlation)


@app.get("/meetings/{source_id}/requirements.pdf")
def meeting_requirements_pdf(source_id: str, company_id: str = Query(alias="companyId", min_length=1),
                             allowed_projects: str = Query(alias="allowedProjects", default=""),
                             x_internal_api_key: Optional[str] = Header(default=None),
                             x_correlation_id: Optional[str] = Header(default=None)):
    """The approved meeting's requirements as a PDF."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    data = _meeting_call(lambda m: m.requirements_pdf(ctx, source_id), correlation)
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", source_id)[:80] or "meeting"
    return Response(content=data, media_type="application/pdf",
                    headers={"Content-Disposition": f'attachment; filename="{safe}-requirements.pdf"'})


# ---------- Requirement memory and open questions ----------

class EditRequirementRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    text: str = Field(min_length=1, max_length=400)
    edited_by: str = Field(min_length=1, max_length=200)


def _requirement_json(r):
    return {"id": r["uid"], "text": r["text"], "status": r["status"], "projectKey": r["project_key"],
            "updatedAt": r.get("updated_at"),
            "changes": [{"type": c["type"], "before": c.get("before"), "after": c.get("after"), "note": c.get("note"),
                         "quote": c.get("quote"), "lines": c.get("lines") or [], "at": c.get("at"), "by": c.get("by"),
                         "meeting": c.get("meeting"), "meetingDate": c.get("meeting_date")}
                        for c in r.get("changes") or []]}


@app.get("/projects/{project_key}/requirements")
def list_requirements(project_key: str, company_id: str = Query(alias="companyId", min_length=1),
                      allowed_projects: str = Query(alias="allowedProjects", default=""),
                      q: Optional[str] = Query(default=None, max_length=300),
                      x_internal_api_key: Optional[str] = Header(default=None),
                      x_correlation_id: Optional[str] = Header(default=None)):
    """The project's requirements with their story across meetings (`q` narrows to what it is about)."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    project = project_key.strip().upper()

    def work(m):
        m._check_scope(ctx, project)
        return m.requirement_history(ctx, question=q, project=project)
    return {"requirements": [_requirement_json(r) for r in _meeting_call(work, correlation)],
            "correlationId": correlation}


@app.patch("/requirements/{requirement_id}")
def edit_requirement(requirement_id: str, request: EditRequirementRequest,
                     x_internal_api_key: Optional[str] = Header(default=None),
                     x_correlation_id: Optional[str] = Header(default=None)):
    """A team member rewords a requirement; its history keeps an "edited" change with who did it."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    found = _meeting_call(lambda m: m.edit_requirement(ctx, requirement_id, request.text, request.edited_by),
                          correlation)
    _answers.clear()
    return {"requirements": [_requirement_json(r) for r in found], "correlationId": correlation}


@app.get("/projects/{project_key}/open-questions")
def list_open_questions(project_key: str, company_id: str = Query(alias="companyId", min_length=1),
                        allowed_projects: str = Query(alias="allowedProjects", default=""),
                        x_internal_api_key: Optional[str] = Header(default=None),
                        x_correlation_id: Optional[str] = Header(default=None)):
    """Questions asked in approved meetings that no later meeting answered: the list for the next meeting."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    found = _meeting_call(lambda m: m.open_questions(ctx, project_key.strip().upper()), correlation)
    return {"openQuestions": [{"id": q["uid"], "text": q["text"], "quote": q.get("quote"), "meeting": q.get("meeting"),
                               "meetingDate": q.get("date")} for q in found], "correlationId": correlation}


# ---------- Live meeting session ----------
# Read-only help during a meeting: nothing reaches Jira or the project's memory before review and approval.

class LiveStartRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    project_key: str = Field(min_length=1, max_length=100)
    title: Optional[str] = Field(default=None, max_length=300)
    started_by: Optional[str] = Field(default=None, max_length=200)


class LiveAssistRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    transcript: str = Field(default="", max_length=400_000)   # everything so far; only new lines are read
    question: Optional[str] = Field(default=None, max_length=400)
    dismiss: List[str] = Field(default_factory=list, max_length=100)   # suggestion ids asked or not needed


class LiveEndRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    transcript: Optional[str] = Field(default=None, max_length=400_000)   # sent: it goes to review as a meeting
    meeting_date: Optional[str] = Field(default=None, max_length=40)
    created_by: Optional[str] = Field(default=None, max_length=200)


def _suggestion_json(g):
    ref = g.get("ref")
    return {"id": g["id"], "kind": g["kind"], "text": g["text"], "quote": g.get("quote"), "lines": g.get("lines") or [],
            "done": g.get("done", False),
            "ref": {"type": ref["type"], "id": ref["uid"], "text": ref["text"], "where": ref.get("where")} if ref else None}


def _live_view(v, correlation):
    return {"sessionId": v["session_id"], "projectKey": v["project"], "title": v.get("title"), "status": v["status"],
            "linesSeen": v["lines_seen"], "startedAt": v.get("started_at"), "sourceId": v.get("source_id"),
            "suggestions": [_suggestion_json(g) for g in v["suggestions"]], "correlationId": correlation}


@app.put("/live-sessions/{session_id}")
def start_live_session(session_id: str, request: LiveStartRequest, x_internal_api_key: Optional[str] = Header(default=None),
                       x_correlation_id: Optional[str] = Header(default=None)):
    """Start (or reopen) a live session for a meeting. The id is the backend's."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    if not re.fullmatch(r"[A-Za-z0-9_.:-]{1,200}", session_id):
        raise HTTPException(400, "bad session id")
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    view = _meeting_call(lambda m: m.live_sessions().start(ctx, session_id, request.project_key, request.title,
                                                           request.started_by), correlation)
    return _live_view(view, correlation)


@app.post("/live-sessions/{session_id}/assist")
def assist_live_session(session_id: str, request: LiveAssistRequest, x_internal_api_key: Optional[str] = Header(default=None),
                        x_correlation_id: Optional[str] = Header(default=None)):
    """Send the transcript so far (and a question, if any): only help not given before comes back."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    result = _meeting_call(lambda m: m.live_sessions().assist(ctx, session_id, request.transcript, request.question,
                                                              request.dismiss), correlation)
    answer = result.get("answer")
    return {"suggestions": [_suggestion_json(g) for g in result["suggestions"]], "linesSeen": result["lines_seen"],
            "answer": {"text": answer["text"], "quote": answer.get("quote"), "lines": answer.get("lines") or []}
            if answer else None, "correlationId": correlation}


@app.get("/live-sessions/{session_id}")
def get_live_session(session_id: str, company_id: str = Query(alias="companyId", min_length=1),
                     allowed_projects: str = Query(alias="allowedProjects", default=""),
                     x_internal_api_key: Optional[str] = Header(default=None),
                     x_correlation_id: Optional[str] = Header(default=None)):
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    return _live_view(_meeting_call(lambda m: m.live_sessions().view(ctx, session_id), correlation), correlation)


class LiveWrapUpRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    transcript: str = Field(min_length=1, max_length=400_000)


@app.post("/live-sessions/{session_id}/wrap-up")
def wrap_up_live_session(session_id: str, request: LiveWrapUpRequest,
                         x_internal_api_key: Optional[str] = Header(default=None),
                         x_correlation_id: Optional[str] = Header(default=None)):
    """Before ending: everything the meeting has not covered yet (details never asked, unclear points,
    open questions from earlier meetings), so the team asks now instead of calling the client again."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    result = _meeting_call(lambda m: m.live_sessions().wrap_up(ctx, session_id, request.transcript), correlation)
    return {"suggestions": [_suggestion_json(g) for g in result["suggestions"]], "correlationId": correlation}


@app.post("/live-sessions/{session_id}/end")
def end_live_session(session_id: str, request: LiveEndRequest, x_internal_api_key: Optional[str] = Header(default=None),
                     x_correlation_id: Optional[str] = Header(default=None)):
    """End the session: questions for the next meeting, and the transcript (when sent) starts the usual
    after-meeting extraction as an online meeting source (`sourceId`)."""
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(request.company_id, request.allowed_projects)
    result = _meeting_call(lambda m: m.live_sessions().end(ctx, session_id, request.transcript, request.meeting_date,
                                                           request.created_by), correlation)
    nxt = result["next_meeting"]
    return {"sessionId": result["session_id"], "status": result["status"], "sourceId": result.get("source_id"),
            "nextMeeting": {"notAsked": nxt["not_asked"],
                            "openQuestions": [{"id": q["uid"], "text": q["text"], "meeting": q.get("meeting"),
                                               "meetingDate": q.get("date")} for q in nxt["open_questions"]]},
            "correlationId": correlation}


@app.delete("/live-sessions/{session_id}", status_code=204)
def delete_live_session(session_id: str, company_id: str = Query(alias="companyId", min_length=1),
                        allowed_projects: str = Query(alias="allowedProjects", default=""),
                        x_internal_api_key: Optional[str] = Header(default=None),
                        x_correlation_id: Optional[str] = Header(default=None)):
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    ctx = _meeting_ctx(company_id, allowed_projects.split(","))
    _meeting_call(lambda m: m.live_sessions().delete(ctx, session_id), correlation)
    return Response(status_code=204)


@app.delete("/ask/{correlation_id}", status_code=204)
def cancel_ask(correlation_id: str, x_internal_api_key: Optional[str] = Header(default=None)):
    """The user added a message before this question's answer came back: stop working on it."""
    _authorize(x_internal_api_key)
    if not correlation_id or len(correlation_id) > 200:
        raise HTTPException(400, "bad correlation id")
    cancel.cancel(correlation_id)
    return Response(status_code=204)


@app.get("/health")
def health(response: Response):
    try:
        run_query("RETURN 1 AS ok")
        return {"status": "ok"}
    except Exception as exc:
        log.error("health check failed: %s", type(exc).__name__)
        response.status_code = 503
        return {"status": "unavailable"}