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
import logging
import os
import secrets
import threading
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Annotated, Dict, List, Literal, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Query, Response
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

load_dotenv()

import cache_version
import cancel
import conversation
import names
from answer_generator import _is_arabic, generate_answer_result
from query_engine import AccessContext, run_query

log = logging.getLogger("syntrace.service")


def _resume_meetings():
    try:
        import meeting_notes
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
    history: List["Turn"] = Field(default_factory=list, max_length=conversation.MAX_TURNS * 2)
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
           ctx.jira_account_id,
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


@app.post("/ask", response_model=AskResponse, response_model_by_alias=True)
def ask(request: AskRequest, x_internal_api_key: Optional[str] = Header(default=None),
        x_correlation_id: Optional[str] = Header(default=None)):
    _authorize(x_internal_api_key)
    correlation = x_correlation_id or uuid.uuid4().hex
    question = request.question.strip()
    if not question:
        raise HTTPException(400, "question is empty")
    ctx = AccessContext(request.company_id, tuple(p.strip().upper() for p in request.allowed_projects if p.strip()),
                        request.jira_account_id,
                        tuple(sorted({p.strip() for p in request.allowed_syntrace_project_ids if p.strip()})))
    history_sent = "history" in request.model_fields_set
    if history_sent:
        turns = conversation.from_history([(t.question, t.answer) for t in request.history])
    else:
        conversation.drop_last(request.company_id, request.employee_id, request.conversation_id,
                               request.edited_turns)
        turns = conversation.recent(request.company_id, request.employee_id, request.conversation_id)
    import timing
    timer = timing.begin()
    started = cancel.start(correlation, ASK_DEADLINE)
    try:
        cancel.check()   # cancelled before it started
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
                       source=result.get("source") or ("ticket" if result["status"] == "ok" else None))


# ---------- Meeting notes ----------
# The backend checks the user's role (PO or PM for writes) and sends the company and projects from
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


class ReviewRequest(CamelModel):
    company_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    reviewer_id: str = Field(min_length=1, max_length=200)
    approve: List[str] = Field(default_factory=list, max_length=500)
    delete: List[str] = Field(default_factory=list, max_length=500)
    links: Dict[str, List[str]] = Field(default_factory=dict, max_length=500)   # item id -> confirmed suggested keys


def _meeting_ctx(company_id, projects):
    return AccessContext(company_id, tuple(p.strip().upper() for p in projects if p.strip()))


def _meeting_call(work, correlation):
    import meeting_notes
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
        "summary": source.get("summary"), "analysisError": source.get("analysis_error"),
        "scope": {"agreed": (source.get("scope") or {}).get("agreed") or [],
                  "outOfScope": (source.get("scope") or {}).get("out_of_scope") or [],
                  "open": (source.get("scope") or {}).get("open") or []},
        "items": [{"id": i["uid"], "type": i["type"], "text": i["text"], "evidence": i["evidence"],
                   "owner": i["owner"], "due": i["due"], "needsReview": i["needs_review"], "status": i["status"],
                   "jiraLinks": i["links"], "suggestedLinks": i.get("suggested") or [],
                   "speaker": i.get("speaker"), "relation": i.get("relation"),
                   "relatedKeys": i.get("related_keys") or [], "relationNote": i.get("relation_note"),
                   "relatedEarlier": [{"id": e["uid"], "type": e["type"], "text": e["text"], "meetingDate": e["date"],
                                       "title": e["title"]} for e in i.get("earlier") or []],
                   "drafts": [{"id": d["uid"], "title": d["title"], "description": d.get("description"),
                               "acceptance": d.get("acceptance") or [], "subtasks": d.get("subtasks") or [],
                               "storyPoints": d.get("story_points"), "estimateHours": d.get("estimate_hours"),
                               "estimateBasedOn": d.get("estimate_based_on") or [], "status": d.get("status")}
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
        request.text, request.pdf_base64, request.created_by, request.linked_source_id), correlation)
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