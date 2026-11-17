"""
cancel.py
Stop a question that the user has added to before its answer came back.

The backend calls DELETE /ask/{correlationId} for the first request, then asks again with both
messages. The first request is still running in this process: every model call checks first
whether its request was cancelled, and stops it with Cancelled. Cancelled is a BaseException on
purpose, so the "a failure falls back to the normal path" handlers do not swallow it.

A cancel can arrive before its request starts, so cancelled ids are kept for a while.
"""
import contextvars
import threading
import time

KEEP_SECONDS = 600
MAX_IDS = 5000

_lock = threading.Lock()
_cancelled = {}   # correlation id -> when it was cancelled
_current = contextvars.ContextVar("syntrace_request", default=None)


class Cancelled(BaseException):
    """The request was cancelled by the backend. Not an Exception, so fallbacks don't catch it."""


def cancel(correlation_id):
    now = time.monotonic()
    with _lock:
        for old in [k for k, t in _cancelled.items() if now - t > KEEP_SECONDS]:
            del _cancelled[old]
        if len(_cancelled) >= MAX_IDS:
            _cancelled.pop(next(iter(_cancelled)))
        _cancelled[correlation_id] = now


def start(correlation_id):
    """Mark the running request. -> a token for finish()."""
    return _current.set(correlation_id)


def finish(token):
    _current.reset(token)


def check():
    """Raise Cancelled when the running request was cancelled. Call it before every model call."""
    correlation_id = _current.get()
    if correlation_id is None:
        return
    with _lock:
        if correlation_id in _cancelled:
            raise Cancelled(correlation_id)
