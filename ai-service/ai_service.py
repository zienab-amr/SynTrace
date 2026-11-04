"""
ai_service.py
HTTP service the backend calls for user questions. It must not be exposed to the internet.

  uvicorn ai_service:app --host 0.0.0.0 --port 8000

Tenant and allowed projects come from the backend, which takes them from the user's JWT.
Question and answer text are never logged.
"""
import logging
import os
import secrets
import uuid
from typing import List, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

load_dotenv()

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


class Link(CamelModel):
    key: str
    url: str


class AskResponse(CamelModel):
    status: str
    answer: str
    links: List[Link]
    correlation_id: str


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
    ctx = AccessContext(request.company_id, tuple(p.strip().upper() for p in request.allowed_projects if p.strip()))
    try:
        result = generate_answer_result(question, ctx)
    except Exception as exc:
        log.error("ask failed correlation=%s error=%s", correlation, type(exc).__name__)
        raise HTTPException(503, "assistant is unavailable") from None
    if result["status"] == "search_unavailable":
        log.error("search unavailable correlation=%s", correlation)
        raise HTTPException(503, "assistant is unavailable")
    return AskResponse(status=result["status"], answer=result["answer"], links=result["links"],
                       correlation_id=correlation)


@app.get("/health")
def health(response: Response):
    try:
        run_query("RETURN 1 AS ok")
        return {"status": "ok"}
    except Exception as exc:
        log.error("health check failed: %s", type(exc).__name__)
        response.status_code = 503
        return {"status": "unavailable"}
