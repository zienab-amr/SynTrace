"""
event_reliability.py
====================
Retry, duplicate suppression and failure journal for event processing.

HONEST SCOPE: there is no durable queue or outbox in this repository, and none is introduced.
  * `RecentEvents` is an in-process LRU. It only avoids redundant work for exact redeliveries
    and is lost on restart. Correctness never depends on it: every write path is idempotent
    and version-ordered (ingest.compare_versions, MERGE by stable uid).
  * The failure journal is a local best-effort directory (RAW_EVENTS_DIR/<tenant>/failed).
    It is NOT an acknowledgement protocol. Redelivery after a failure is the caller's
    (backend's) responsibility; `EventResult.retryable` tells it whether redelivery can help.
"""
import json
import os
import random
import re
import sys
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Optional


def safe_console():
    """A log line must never fail an event. On Windows, redirected output uses a legacy
    encoding that cannot print some characters, and the error would reject the event."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="backslashreplace")


@dataclass
class EventResult:
    status: str                       # legacy status string ("upserted", "deleted", ...)
    outcome: str                      # applied|duplicate|stale|ambiguous|ignored|rejected|failed
    event_id: Optional[str] = None
    retryable: bool = False           # True: redelivery may succeed (transient failure)
    attempts: int = 1
    error: Optional[str] = None
    detail: Dict[str, Any] = field(default_factory=dict)


class EventProcessingError(RuntimeError):
    def __init__(self, result: EventResult):
        super().__init__(f"{result.outcome}: {result.error}")
        self.result = result
        self.retryable = result.retryable


class RecentEvents:
    def __init__(self, maxlen=10000):
        self.maxlen, self._d = maxlen, OrderedDict()

    def seen(self, event_id):
        if event_id in self._d:
            self._d.move_to_end(event_id)
            return True
        return False

    def mark(self, event_id):
        self._d[event_id] = True
        self._d.move_to_end(event_id)
        while len(self._d) > self.maxlen:
            self._d.popitem(last=False)

    def clear(self):
        self._d.clear()


def is_transient(exc):
    """Failures where trying again can plausibly succeed."""
    names = {c.__name__ for c in type(exc).__mro__}
    if names & {"TransientError", "ServiceUnavailable", "SessionExpired", "DatabaseUnavailable",
                "JiraTransientError", "ConnectionError", "TimeoutError", "ConnectionResetError"}:
        return True
    return bool(getattr(exc, "retryable", False))


def run_with_retry(fn, *, max_attempts=5, base=0.5, cap=30.0, sleep=time.sleep,
                   rng=random.random, transient=is_transient, log=print):
    """-> (value, attempts). Retries only transient errors, with exponential backoff and
    full jitter. The last exception is re-raised when attempts are exhausted or the error is
    permanent (identity conflict, bad payload, scope error...)."""
    attempt = 0
    while True:
        attempt += 1
        try:
            return fn(), attempt
        except Exception as exc:
            if attempt >= max_attempts or not transient(exc):
                exc.attempts = attempt
                raise
            delay = rng() * min(cap, base * (2 ** (attempt - 1)))
            log(f"  ⚠ transient failure ({type(exc).__name__}); retry {attempt}/{max_attempts - 1} "
                f"in {delay:.2f}s")
            sleep(delay)


def _safe(s):
    return re.sub(r"[^A-Za-z0-9_.-]", "_", str(s))


def journal_failure(raw_dir, tenant_id, payload, *, error, retryable, event_id=None,
                    site_id=None, delivery_id=None):
    folder = os.path.join(raw_dir, _safe(tenant_id), "failed")
    os.makedirs(folder, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    path = os.path.join(folder, f"{ts}_{_safe(event_id or 'noid')}.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"tenant_id": tenant_id, "site_id": site_id, "delivery_id": delivery_id,
                   "event_id": event_id, "error": error, "retryable": retryable,
                   "failed_at": ts, "payload": payload}, fh, ensure_ascii=False, indent=2)
    return path


def replay_failed(raw_dir, tenant_id, process, *, only_retryable=True, limit=None):
    """Re-run journaled failures through `process(payload, tenant_id, site_id=..., delivery_id=...)`.
    Safe to repeat: processing is idempotent and version-ordered. A file is removed only after
    `process` returns without raising. Returns {"replayed": n, "failed": n, "skipped": n}."""
    folder = os.path.join(raw_dir, _safe(tenant_id), "failed")
    stats = {"replayed": 0, "failed": 0, "skipped": 0}
    if not os.path.isdir(folder):
        return stats
    for name in sorted(os.listdir(folder)):
        if limit is not None and sum(stats.values()) >= limit:
            break
        path = os.path.join(folder, name)
        try:
            with open(path, encoding="utf-8") as fh:
                rec = json.load(fh)
        except (OSError, ValueError):
            stats["skipped"] += 1
            continue
        if only_retryable and not rec.get("retryable"):
            stats["skipped"] += 1
            continue
        try:
            process(rec["payload"], tenant_id, site_id=rec.get("site_id"),
                    delivery_id=rec.get("delivery_id"))
            os.remove(path)
            stats["replayed"] += 1
        except Exception:
            stats["failed"] += 1
    return stats
