"""
timing.py
Where one question's time goes: the planner, the agent's model calls, its graph tools, search and
the answer. ai_service logs it with the correlation id at the end of each question, without the
question text, so a slow or failed answer can be traced to its stage.
"""
import contextvars
import time
from contextlib import contextmanager

_current = contextvars.ContextVar("syntrace_timing", default=None)


def begin():
    return _current.set({"started": time.monotonic(), "stages": {}, "llm_calls": 0, "errors": [],
                         "tokens": 0, "cached": 0})


def end(token):
    _current.reset(token)


def add(stage, seconds, llm=False):
    data = _current.get()
    if data is None:
        return
    data["stages"][stage] = round(data["stages"].get(stage, 0.0) + seconds, 2)
    data["llm_calls"] += 1 if llm else 0


def tokens(used, cached=0):
    data = _current.get()
    if data is not None:
        data["tokens"] += used
        data["cached"] += cached


def error(kind):
    """A safe label of a failure, such as "BadRequestError:400:tool_use_failed". Never the message text."""
    data = _current.get()
    if data is not None and len(data["errors"]) < 10:
        data["errors"].append(kind)


@contextmanager
def stage(name, llm=False):
    started = time.monotonic()
    try:
        yield
    finally:
        add(name, time.monotonic() - started, llm)


def summary():
    data = _current.get()
    if data is None:
        return {}
    return {"seconds": round(time.monotonic() - data["started"], 2), "stages": dict(data["stages"]),
            "llm_calls": data["llm_calls"], "tokens": data["tokens"], "cached_tokens": data["cached"],
            "errors": list(data["errors"])}


def error_label(exc):
    """The error type, HTTP status and the provider's error code, which hold no secret or question."""
    status = getattr(exc, "status_code", None)
    code = None
    body = getattr(exc, "body", None)
    if isinstance(body, dict):
        inner = body.get("error") if isinstance(body.get("error"), dict) else body
        code = inner.get("code") if isinstance(inner, dict) else None
    return ":".join(str(x) for x in (type(exc).__name__, status, code) if x)
