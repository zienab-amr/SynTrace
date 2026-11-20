"""
event_adapter.py
================
Classifies an inbound event into one canonical Envelope without changing either wire format.

Two formats reach this component (see README.md):

1. NATIVE JIRA WEBHOOK (the contract webhook_handler.py has always consumed):
     {"webhookEvent": "jira:issue_updated", "timestamp": <epoch ms>, "user": {...},
      "issue": {...}, "changelog": {"id": "...", "items": [...]}, "comment": {...}, ...}
   Unchanged. Event name = "<entity>_<action>" with an optional "jira:" prefix.

2. INTERNAL DELETION NOTICE produced by the application BACKEND (not by this repository):
     {"type": "issue" | "project" | "comment" | "worklog" | "sprint" | "user" | "board" |
              "issuetype" | "attachment", "id": <string|number>}
   The backend owns producing it. It carries NO tenant and NO Jira site, so both must come from
   the authenticated call context (`tenant_id` argument, `site_id` argument or JIRA_SITE_ID).
   Optional extra fields are accepted but never required: tenant_id, site_id/jira_site_id,
   timestamp/deleted_at, key (issue key), project_key. `id` meaning is not specified by the
   backend; it is interpreted as: all digits -> Jira numeric id, issue-key shape -> issue key,
   anything else for project -> project key.

Scope: every envelope carries tenant_id and site_id. If neither the call context, configuration
nor the payload can name the Jira site, the event is rejected (EventScopeError) instead of
being written under a guessed site. If an explicit site that looks like a hostname disagrees
with the host in the payload's own `self` URLs, the event is rejected as cross-site.
"""
import hashlib
import json
import os
import re
from dataclasses import dataclass, field
from typing import Any, Dict, Optional
from urllib.parse import urlparse

INTERNAL_ALLOWED_KEYS = {"type", "id", "tenant_id", "site_id", "jira_site_id", "timestamp",
                         "deleted_at", "key", "project_key"}
INTERNAL_TYPES = {"issue", "project", "comment", "worklog", "sprint", "user", "board",
                  "issuetype", "attachment"}
ISSUE_KEY_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*-\d+$")
_SITE_CLEAN = re.compile(r"[^A-Za-z0-9_.-]")


class EventScopeError(ValueError):
    """Event cannot be tied safely to one tenant and one Jira site."""


@dataclass
class Envelope:
    format: str                      # "jira" | "internal_deletion"
    event: str                       # webhookEvent or "internal:<type>_deleted"
    entity: str
    action: str
    tenant_id: str
    site_id: str
    event_id: str
    event_time: Any = None           # epoch ms / ISO, as received
    payload: Dict = field(default_factory=dict)


def is_internal_deletion(payload):
    return (isinstance(payload, dict) and "webhookEvent" not in payload
            and "type" in payload and "id" in payload
            and set(payload) <= INTERNAL_ALLOWED_KEYS)


def split_event(name):
    name = (name or "").replace("jira:", "", 1)
    entity, _, action = name.partition("_")
    return entity.lower(), action.lower()


def _norm_site(value):
    return _SITE_CLEAN.sub("_", str(value).strip().lower())


def _self_hosts(payload):
    hosts = set()
    for k in ("issue", "comment", "worklog", "sprint", "project", "user", "board"):
        obj = payload.get(k)
        if isinstance(obj, dict):
            h = urlparse(obj.get("self") or "").hostname
            if h:
                hosts.add(h.lower())
    return hosts


def resolve_site(payload, site_id=None):
    """Explicit (argument / payload field / JIRA_SITE_ID) first, else payload `self` host,
    else JIRA_BASE_URL host. Raises EventScopeError when nothing identifies the site or
    when an explicit hostname-like site contradicts the payload."""
    explicit = (site_id or payload.get("site_id") or payload.get("jira_site_id")
                or os.getenv("JIRA_SITE_ID") or None)
    hosts = _self_hosts(payload)
    if len(hosts) > 1:
        raise EventScopeError(f"payload references several Jira hosts: {sorted(hosts)}")
    if explicit:
        explicit = _norm_site(explicit)
        if "." in explicit and hosts and explicit not in {_norm_site(h) for h in hosts}:
            raise EventScopeError(
                f"site mismatch: configured {explicit!r} but payload is from {sorted(hosts)}")
        return explicit
    if hosts:
        return _norm_site(next(iter(hosts)))
    base = urlparse(os.getenv("JIRA_BASE_URL", "")).hostname
    if base:
        return _norm_site(base)
    raise EventScopeError("Jira site unknown: pass site_id, set JIRA_SITE_ID, or include "
                          "object `self` URLs in the payload")


def _fingerprint(parts):
    return hashlib.sha256(json.dumps(parts, sort_keys=True, default=str).encode()).hexdigest()[:32]


def adapt(payload, tenant_id, *, site_id=None, delivery_id=None) -> Envelope:
    if not isinstance(payload, dict):
        raise EventScopeError("payload must be a JSON object")
    if not tenant_id:
        raise EventScopeError("tenant_id is required")
    if payload.get("tenant_id") not in (None, tenant_id):
        raise EventScopeError(
            f"tenant mismatch: call context {tenant_id!r} vs payload {payload.get('tenant_id')!r}")
    site = resolve_site(payload, site_id)

    if is_internal_deletion(payload):
        etype = str(payload["type"]).strip().lower()
        if etype not in INTERNAL_TYPES:
            raise EventScopeError(f"unsupported internal deletion type {payload['type']!r}")
        if str(payload["id"]).strip() == "":
            raise EventScopeError("internal deletion has an empty id")
        parts = ["internal", tenant_id, site, etype, str(payload["id"]).strip()]
        eid = _fingerprint([delivery_id] if delivery_id else parts)
        return Envelope("internal_deletion", f"internal:{etype}_deleted", etype, "deleted",
                        tenant_id, site, eid,
                        payload.get("deleted_at") or payload.get("timestamp"), payload)

    event = payload.get("webhookEvent")
    entity, action = split_event(event)
    g = lambda k, f: ((payload.get(k) or {}).get(f) if isinstance(payload.get(k), dict) else None)
    parts = ["jira", tenant_id, site, event, payload.get("timestamp"), g("issue", "id"),
             g("issue", "key"), g("changelog", "id"), g("comment", "id"), g("comment", "updated"),
             g("worklog", "id"), g("worklog", "updated"), g("sprint", "id"), g("sprint", "state"),
             g("project", "id"), g("project", "key"), g("user", "accountId"),
             payload.get("issue_event_type_name")]
    eid = _fingerprint([tenant_id, site, delivery_id] if delivery_id else parts)
    return Envelope("jira", event or "unknown", entity, action, tenant_id, site, eid,
                    payload.get("timestamp"), payload)
