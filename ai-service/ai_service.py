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
import time
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

load_dotenv()

import cache_version
import cancel
import conversation
import names
from answer_generator import generate_answer_result
from query_engine import AccessContext, run_query

log = logging.getLogger("syntrace.service")
app = FastAPI(title="SynTrace AI", docs_url=None, redoc_url=None, openapi_url=None)


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class AskRequest(CamelModel):
    question: str = Field(min_length=1, max_length=2000)
    company_id: str = Field(min_length=1, max_length=200)
    employee_id: str = Field(min_length=1, max_length=200)
    allowed_projects: List[str] = Field(default_factory=list, max_length=5000)
    jira_account_id: Optional[str] = Field(default=None, max_length=200)
    # One chat in the app. Follow-up questions are read in the context of the same chat only.
    conversation_id: Optional[str] = Field(default=None, max_length=200)
    # The chat's last questions and answers, oldest first, when the backend keeps the chat history.
    # When it is sent, the service uses it instead of its own short memory.
    history: List["Turn"] = Field(default_factory=list, max_length=conversation.MAX_TURNS * 2)
    # The user edited an earlier question: how many of the chat's last questions to forget first,
    # counting the edited one. Only needed while the backend does not send history.
    edited_turns: int = Field(default=0, ge=0, le=50)
    # Messages the user sent before this one that have no answer yet, oldest first. They are answered
    # together with this one; the backend cancels their own requests with DELETE /ask/{correlationId}.
    added_to: List[str] = Field(default_factory=list, max_length=5)


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
    key = (ctx.tenant_id, version, datetime.now(timezone.utc).date(), ctx.allowed_projects, ctx.jira_account_id,
           " ".join(question.lower().split()))
    now = time.monotonic()
    cached = _answers.get(key)
    if cached and now - cached[0] < CACHE_SECONDS:
        return cached[1]
    result = generate_answer_result(question, ctx)
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
                        request.jira_account_id)
    if request.history:
        turns = conversation.from_history([(t.question, t.answer) for t in request.history])
    else:
        conversation.drop_last(request.company_id, request.employee_id, request.conversation_id,
                               request.edited_turns)
        turns = conversation.recent(request.company_id, request.employee_id, request.conversation_id)
    started = cancel.start(correlation)
    try:
        cancel.check()   # cancelled before it started
        if request.added_to:
            asked = conversation.merge([m[:2000] for m in request.added_to] + [question], turns)
        else:
            asked = conversation.standalone(question, turns)
        result = _cached_answer(asked, ctx)
    except cancel.Cancelled:
        log.info("cancelled correlation=%s", correlation)
        raise HTTPException(409, "cancelled") from None
    except Exception as exc:
        log.error("ask failed correlation=%s error=%s", correlation, type(exc).__name__)
        raise HTTPException(503, "assistant is unavailable") from None
    finally:
        cancel.finish(started)
    try:
        result["answer"] = names.latinize(result["answer"], names.people(ctx))
    except Exception as exc:   # a name list problem must never fail the answer
        log.warning("name check failed: %s", type(exc).__name__)
    if result["status"] == "ok" and not request.history:
        conversation.remember(request.company_id, request.employee_id, request.conversation_id,
                              asked, result["answer"], result["links"])
    _record_unanswered(question, request.company_id, result["status"], correlation)
    if result["status"] == "search_unavailable":
        log.error("search unavailable correlation=%s", correlation)
        raise HTTPException(503, "assistant is unavailable")
    return AskResponse(status=result["status"], answer=result["answer"], links=result["links"],
                       correlation_id=correlation,
                       source=result.get("source") or ("ticket" if result["status"] == "ok" else None))


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