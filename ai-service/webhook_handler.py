"""
webhook_handler.py
بياخد payload من Jira webhook (أو mock JSON، أو internal deletion notice {type,id} من الـ backend)
ويحدّث الـ Graph عن طريق ingest.py (نفس كود الـ bulk import بالظبط).

- الـ raw payload بيتخزن الأول (best-effort journal محلي، مش durable queue).
- اسم الـ event بيتفك بشكل عام: "<entity>_<action>"، فأي entity جديد ما بيكسرش حاجة.
- Delete = مسح فعلي كامل من غير أي أثر؛ لو العنصر اتبعت تاني بيتخزن تاني.
- Phase 3: event_adapter بيدعم الصيغتين من غير ما يغيّر أي واحدة، و scope بالـ tenant + Jira site.
  الـ ordering بيتحكم فيه ingest.compare_versions؛ لو مش قابل للإثبات بنعمل authoritative read.
  process_webhook_event(...) بترجّع status string (زي قبل) وبترفع EventProcessingError لو فشل؛
  handle_event(...) بترجّع EventResult فيه outcome/retryable بدون exceptions.
"""
import glob
import json
import os
import random
import re
import time
from datetime import datetime, timezone

from dotenv import load_dotenv

import event_adapter
import event_reliability as rel
import ingest

rel.safe_console()

load_dotenv()

RAW_EVENTS_DIR = os.getenv("RAW_EVENTS_DIR", "raw_events")
MOCK_DIR = os.getenv("MOCK_DIR", "mock_events")
FIELD_REFRESH_MIN_INTERVAL = 300.0

_driver = None
_recent = rel.RecentEvents()
_last_field_refresh = [0.0]


def get_driver():
    global _driver
    if _driver is None:
        from neo4j import GraphDatabase
        _driver = GraphDatabase.driver(
            os.getenv("NEO4J_URI"), auth=(os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASSWORD")))
    return _driver


def _safe(s):
    return re.sub(r"[^A-Za-z0-9_.-]", "_", str(s))


def save_raw(payload, tenant_id):
    """Opt-in (SAVE_RAW_EVENTS=1): payloads hold comment text and user names, so by default
    nothing is written to disk. Returns the path, or None when disabled."""
    if os.getenv("SAVE_RAW_EVENTS") != "1":
        return None
    folder = os.path.join(RAW_EVENTS_DIR, _safe(tenant_id))
    os.makedirs(folder, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = payload.get("webhookEvent") or f"internal_{payload.get('type', 'unknown')}"
    path = os.path.join(folder, f"{ts}_{_safe(name)}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    return path


split_event = event_adapter.split_event


def find_entity_obj(payload, entity):
    """بيدور على الـ object بإسم الـ entity (case-insensitive): issueType, board, sprint..."""
    for k, v in payload.items():
        if k.lower() == entity and isinstance(v, dict):
            return v
    return None


def _ctx_site(ctx, obj=None):
    """Site scope: the envelope's resolved site wins; fall back to object self/config."""
    if ctx and ctx.get("site"):
        return ctx["site"]
    return ingest.jira_site_id(obj)


# ==================================================
# Handlers: (tx, payload, action, tenant) -> status
# ==================================================

def on_issue(tx, payload, action, tenant, ctx=None):
    issue = find_entity_obj(payload, "issue")
    if not issue or not issue.get("key"):
        return "no_issue_object"
    if action == "deleted":
        site = _ctx_site(ctx, issue)
        ingest.delete_issue(tx, issue["key"], tenant, jira_id=issue.get("id"),
                            site_id=site, deletion_time=payload.get("timestamp"),
                            issue_type=((issue.get("fields") or {}).get("issuetype") or {}).get("name"))
        print(f"  ✓ {issue['key']} deleted (hard delete)")
        return "deleted"
    detail = ingest.upsert_issue_detailed(
        tx, issue, tenant,
        changelog=payload.get("changelog"),
        actor=payload.get("user"),
        event_time=ingest.to_utc_iso(payload.get("timestamp")),
        payload_mode="partial", site_id=(ctx or {}).get("site"),
        field_meta=(ctx or {}).get("field_meta"), browse_base=(ctx or {}).get("browse_base"))
    if ctx is not None:
        ctx["detail"] = detail
        ctx["issue_ref"] = {"id": issue.get("id"), "key": issue["key"]}
    status = detail["status"]
    moved = f" (moved from {detail['moved_from']})" if detail.get("moved_from") else ""
    print(f"  ✓ {issue['key']} {action}: {status}{moved}")
    return status


def on_comment(tx, payload, action, tenant, ctx=None):
    c = find_entity_obj(payload, "comment")
    if not c or "id" not in c:
        return "no_comment_object"
    issue_obj = find_entity_obj(payload, "issue") or {}
    site = _ctx_site(ctx, issue_obj)
    if action == "deleted":
        ingest.delete_entity(tx, "Comment", f"{tenant}:site:{site}:comment:{c['id']}", tenant, site,
                             payload.get("timestamp"))
        print(f"  ✓ Comment {c['id']} deleted (hard delete)")
        return "deleted"
    issue_key = issue_obj.get("key")
    status = ingest.upsert_comment(tx, c, tenant, issue_key, site)
    print(f"  ✓ Comment {c['id']} on {issue_key}: {status}")
    return status


def on_sprint(tx, payload, action, tenant, ctx=None):
    s = find_entity_obj(payload, "sprint")
    if not s or "id" not in s:
        return "no_sprint_object"
    site = _ctx_site(ctx, find_entity_obj(payload, "issue") or s)
    if action == "deleted":
        ingest.delete_by_uid(tx, "Sprint", f"{tenant}:site:{site}:sprint:{s['id']}")
        print(f"  ✓ Sprint {s['id']} deleted (hard delete)")
        return "deleted"
    ingest.upsert_sprint(tx, s, tenant, site)   # created/updated/started/closed كلهم نفس المعالجة
    print(f"  ✓ Sprint {s['id']} ({s.get('name')}) {action}")
    return "upserted"


def on_project(tx, payload, action, tenant, ctx=None):
    p = find_entity_obj(payload, "project")
    if not p or not (p.get("key") or p.get("id") is not None):
        return "no_project_object"
    site = _ctx_site(ctx, p)
    if action in ("deleted", "soft_deleted"):
        count = ingest.delete_project(tx, p.get("key"), tenant, site_id=site,
                                      deletion_time=payload.get("timestamp"),
                                      project_id=p.get("id"), soft=(action == "soft_deleted"))
        print(f"  ✓ Project {p.get('key') or p.get('id')} deleted with {count} represented issues")
        return "deleted"
    if action == "restored_deleted":
        # Jira restored the project from trash. Its data was physically removed here, so a
        # full import from the backend is required.
        print(f"  ✓ Project {p.get('key') or p.get('id')} restored: full resync required")
        return "restored_resync_required"
    if not p.get("key"):
        return "no_project_object"
    ingest.upsert_project(tx, {**p}, tenant, site_id=site)
    print(f"  ✓ Project {p['key']} {action}")
    return "upserted"


def on_user(tx, payload, action, tenant, ctx=None):
    u = find_entity_obj(payload, "user")
    if not u or not u.get("accountId"):
        return "no_user_object"
    if action == "deleted":
        ingest.delete_by_uid(tx, "Person", f"{tenant}:person:{u['accountId']}")
        print(f"  ✓ Person {u['accountId']} deleted (hard delete)")
        return "deleted"
    ingest.upsert_person(tx, u, tenant)
    print(f"  ✓ Person {u['accountId']} {action}")
    return "upserted"


def on_worklog(tx, payload, action, tenant, ctx=None):
    w = find_entity_obj(payload, "worklog")
    if not w or "id" not in w:
        return "no_worklog_object"
    site = _ctx_site(ctx, find_entity_obj(payload, "issue") or w)
    if action == "deleted":
        ingest.delete_entity(tx, "Worklog", f"{tenant}:site:{site}:worklog:{w['id']}", tenant, site,
                             payload.get("timestamp"))
        print(f"  ✓ Worklog {w['id']} deleted (hard delete)")
        return "deleted"
    status = ingest.upsert_worklog(tx, w, tenant, site)
    print(f"  ✓ Worklog {w['id']} {action}: {status}")
    return status


def on_attachment(tx, payload, action, tenant, ctx=None):
    a = find_entity_obj(payload, "attachment")
    if not a or a.get("id") is None:
        return "no_attachment_object"
    issue_obj = find_entity_obj(payload, "issue") or {}
    site = _ctx_site(ctx, issue_obj or a)
    if action == "deleted":
        ingest.delete_by_uid(tx, "Attachment", f"{tenant}:site:{site}:attachment:{a['id']}")
        return "deleted"
    known = ingest.upsert_attachment(tx, a, tenant, site, issue_id=issue_obj.get("id") or a.get("issueId"),
                                     issue_key=issue_obj.get("key"))
    return "upserted" if known else "stored_raw_only"


def on_issuelink(tx, payload, action, tenant, ctx=None):
    link = find_entity_obj(payload, "issuelink")
    if not link or not link.get("sourceIssueId") or not link.get("destinationIssueId"):
        return "no_issuelink_object"
    done = ingest.apply_issue_link(tx, link, tenant, _ctx_site(ctx, link), remove=(action == "deleted"))
    return ("deleted" if action == "deleted" else "upserted") if done else "stored_raw_only"


def make_generic_handler(entity, label):
    """IssueType / Board: بنخزّن الـ scalar properties بس. الـ label من whitelist (مش من الـ payload)."""
    def handler(tx, payload, action, tenant, ctx=None):
        obj = find_entity_obj(payload, entity)
        if not obj or obj.get("id") is None:
            return f"no_{entity}_object"
        uid = f"{tenant}:{label.lower()}:{obj['id']}"
        if action == "deleted":
            ingest.delete_by_uid(tx, label, uid)
            print(f"  ✓ {label} {obj['id']} deleted (hard delete)")
            return "deleted"
        props = {k: v for k, v in obj.items()
                 if isinstance(v, (str, int, float, bool)) and k != "self"}
        props["tenant_id"] = tenant
        tx.run(f"MERGE (n:{label} {{uid: $uid}}) SET n += $props", uid=uid, props=props)
        print(f"  ✓ {label} {obj['id']} {action}")
        return "upserted"
    return handler




# ==================================================
# Internal deletion notice {type, id} (produced by the backend)
# ==================================================

def on_internal_deletion(tx, env, ctx):
    p, tenant, site = env.payload, env.tenant_id, env.site_id
    etype, raw_id = env.entity, str(env.payload["id"]).strip()
    when = env.event_time
    if etype == "issue":
        if raw_id.isdigit():
            ingest.delete_issue_by_id(tx, raw_id, tenant, site, when)
        elif event_adapter.ISSUE_KEY_RE.match(raw_id):
            ingest.delete_issue(tx, raw_id.upper(), tenant, site_id=site, deletion_time=when)
        else:
            return "unrecognized_issue_id"
        return "deleted"
    if etype == "project":
        if raw_id.isdigit():
            ingest.delete_project(tx, p.get("project_key"), tenant, site_id=site,
                                  deletion_time=when, project_id=raw_id)
        else:
            ingest.delete_project(tx, raw_id.upper(), tenant, site_id=site, deletion_time=when)
        return "deleted"
    if etype in ("comment", "worklog"):
        label = etype.capitalize()
        ingest.delete_entity(tx, label, f"{tenant}:site:{site}:{etype}:{raw_id}", tenant, site, when)
        return "deleted"
    uids = {"sprint": ("Sprint", f"{tenant}:site:{site}:sprint:{raw_id}"),
            "attachment": ("Attachment", f"{tenant}:site:{site}:attachment:{raw_id}"),
            "user": ("Person", f"{tenant}:person:{raw_id}"),
            "board": ("Board", f"{tenant}:board:{raw_id}"),
            "issuetype": ("IssueType", f"{tenant}:issuetype:{raw_id}")}
    label, uid = uids[etype]
    ingest.delete_by_uid(tx, label, uid)
    return "deleted"


ENTITY_HANDLERS = {
    "issue": on_issue,
    "comment": on_comment,
    "sprint": on_sprint,
    "project": on_project,
    "user": on_user,
    "worklog": on_worklog,
    "attachment": on_attachment,
    "issuelink": on_issuelink,
    "issuetype": make_generic_handler("issuetype", "IssueType"),
    "board": make_generic_handler("board", "Board"),
}

OUTCOME_OF_STATUS = {
    "upserted": "applied", "deleted": "applied", "restored_resync_required": "applied",
    "state_skipped_stale": "stale", "skipped_stale": "stale",
    "state_skipped_ambiguous": "ambiguous",
    "stored_raw_only": "ignored",
}


def _outcome(status):
    if status in OUTCOME_OF_STATUS:
        return OUTCOME_OF_STATUS[status]
    return "rejected" if (status.startswith("no_") or status.startswith("unrecognized")) else "applied"


def maybe_refresh_field_meta(reader, issue):
    """New custom fields appear in Jira at any time. If an event carries a customfield id the
    catalog has never seen, refresh it (at most every FIELD_REFRESH_MIN_INTERVAL seconds)."""
    if reader is None or not isinstance(issue, dict):
        return
    unknown = ingest.field_catalog.unknown_field_ids(issue.get("fields"), ingest.FIELD_META)
    if not unknown or time.time() - _last_field_refresh[0] < FIELD_REFRESH_MIN_INTERVAL:
        return
    _last_field_refresh[0] = time.time()
    try:
        n = ingest.refresh_field_meta(reader.get_fields())
        print(f"  ↻ field catalog refreshed ({n} fields; unknown: {unknown[:5]})")
    except Exception as e:   # catalog refresh must never fail an event
        print(f"  ⚠ field catalog refresh failed: {e}")


def _resolve_ambiguity(env, ctx, reader, session_factory, retry_kw):
    """State order could not be proven from the event. Read the issue from Jira (outside any
    Neo4j transaction), then apply it as an authoritative snapshot unless provably older.
    A 404/403 is NOT a deletion signal: the issue stays flagged `reconcile_needed`."""
    ref = ctx.get("issue_ref") or {}
    target = ref.get("id") or ref.get("key")
    if not target:
        return None
    fetched = reader.get_issue(target)
    if fetched.status != "found":
        return {"authoritative_read": fetched.status}

    def apply():
        with session_factory() as session:
            return session.execute_write(
                lambda tx: ingest.upsert_issue_detailed(
                    tx, fetched.issue, env.tenant_id, payload_mode="full",
                    site_id=env.site_id, authoritative=True))
    detail, _ = rel.run_with_retry(apply, **retry_kw)
    return {"authoritative_read": "found", "applied_status": detail["status"], "detail": detail}


def handle_event(payload, tenant_id=ingest.DEFAULT_TENANT, *, site_id=None, delivery_id=None,
                 jira_reader=None, session_factory=None, sleep=time.sleep, rng=random.random,
                 max_attempts=5, backoff_base=0.5, backoff_cap=30.0, recent=None,
                 field_meta=None, browse_base=None):
    """Process one event; never raises for processing problems, returns EventResult.

    ack guidance for the caller (there is no queue here): outcome in applied/stale/ambiguous/
    ignored/duplicate -> nothing more to do (ambiguous is flagged in the graph until
    a newer event or snapshot clears it); outcome "failed" with retryable=True -> redeliver later;
    outcome "rejected" -> redelivery cannot help, inspect the journal entry."""
    recent = _recent if recent is None else recent
    session_factory = session_factory or (lambda: get_driver().session())
    retry_kw = dict(max_attempts=max_attempts, base=backoff_base, cap=backoff_cap,
                    sleep=sleep, rng=rng)
    try:
        env = event_adapter.adapt(payload, tenant_id, site_id=site_id, delivery_id=delivery_id)
    except event_adapter.EventScopeError as exc:
        _journal(tenant_id, payload, str(exc), False, None, site_id, delivery_id)
        return rel.EventResult("rejected_scope", "rejected", error=str(exc))

    if recent.seen(env.event_id):
        return rel.EventResult("duplicate_suppressed", "duplicate", env.event_id)

    try:
        raw_path = save_raw(payload, tenant_id)
    except OSError as exc:   # a journal problem must not block processing
        raw_path = None
        print(f"  ⚠ raw payload not stored: {exc}")

    if env.format == "internal_deletion":
        handler = on_internal_deletion
    else:
        handler = ENTITY_HANDLERS.get(env.entity)
        if handler is None:
            print(f"  ⚠ Unknown event '{env.event}': ignored" + (f" (raw stored: {raw_path})" if raw_path else ""))
            recent.mark(env.event_id)
            return rel.EventResult("stored_raw_only", "ignored", env.event_id)
    if env.entity == "issue" and env.format == "jira":
        maybe_refresh_field_meta(jira_reader, payload.get("issue"))

    ctx = {}

    def attempt():
        ctx.clear()
        ctx["site"] = env.site_id
        ctx["field_meta"], ctx["browse_base"] = field_meta, browse_base
        with session_factory() as session:
            if env.format == "internal_deletion":
                return session.execute_write(handler, env, ctx)
            return session.execute_write(handler, payload, env.action, tenant_id, ctx)

    try:
        status, attempts = rel.run_with_retry(attempt, **retry_kw)
    except Exception as exc:
        retryable = rel.is_transient(exc)
        _journal(tenant_id, payload, f"{type(exc).__name__}: {exc}", retryable,
                 env.event_id, env.site_id, delivery_id)
        return rel.EventResult("failed" if retryable else "rejected_error",
                               "failed" if retryable else "rejected", env.event_id,
                               retryable, getattr(exc, "attempts", 1),
                               f"{type(exc).__name__}: {exc}")

    outcome = _outcome(status)
    detail = dict(ctx.get("detail") or {})
    if status == "state_skipped_ambiguous" and jira_reader is not None:
        try:
            resolved = _resolve_ambiguity(env, ctx, jira_reader, session_factory, retry_kw)
        except Exception as exc:   # Jira unreachable: stays flagged
            resolved = {"authoritative_read": f"error:{type(exc).__name__}"}
        if resolved:
            detail["resolution"] = {k: v for k, v in resolved.items() if k != "detail"}
            if resolved.get("applied_status") == "upserted":
                status, outcome = "upserted", "applied"
                detail["uid"] = (resolved.get("detail") or {}).get("uid")
    if outcome in ("applied", "stale", "ambiguous"):
        recent.mark(env.event_id)
    if (outcome == "applied" and env.entity == "issue" and env.action != "deleted"
            and env.format == "jira" and os.getenv("EMBED_ON_WEBHOOK") == "1"):
        try:
            from build_embeddings import embed_work_items
            uid = detail.get("uid")
            if uid:
                embed_work_items(tenant_id, uids=[uid])
        except Exception as e:  # الـ embedding مش لازم يكسر الـ webhook
            print(f"  ⚠ embedding skipped: {e}")
    return rel.EventResult(status, outcome, env.event_id, False, attempts, None, detail)


def _journal(tenant_id, payload, error, retryable, event_id, site_id, delivery_id):
    # Opt-in (JOURNAL_FAILED_EVENTS=1). In the service a failure is a NACK and the backend
    # redelivers; a local copy of the payload is not needed (and would hold tenant data).
    if os.getenv("JOURNAL_FAILED_EVENTS") != "1":
        return
    try:
        rel.journal_failure(RAW_EVENTS_DIR, tenant_id, payload, error=error, retryable=retryable,
                            event_id=event_id, site_id=site_id, delivery_id=delivery_id)
    except OSError as e:
        print(f"  ⚠ failure journal not written: {e}")


EventProcessingError = rel.EventProcessingError


def process_webhook_event(payload, tenant_id=ingest.DEFAULT_TENANT, **kwargs):
    """Legacy entry point: returns the status string, raises EventProcessingError when the
    event could not be processed (transient failure after retries, or permanent rejection)."""
    result = handle_event(payload, tenant_id, **kwargs)
    if result.error:
        raise rel.EventProcessingError(result)
    return result.status


def replay_failed_events(tenant_id=ingest.DEFAULT_TENANT, **kwargs):
    """Re-run retryable journaled failures (idempotent). See event_reliability.replay_failed."""
    return rel.replay_failed(RAW_EVENTS_DIR, tenant_id, process_webhook_event, **kwargs)


def process_mock_file(filepath, tenant_id=ingest.DEFAULT_TENANT):
    with open(filepath, "r", encoding="utf-8") as f:
        payload = json.load(f)
    print(f"\n=== {filepath} (event: {payload.get('webhookEvent')}) ===")
    return process_webhook_event(payload, tenant_id)


if __name__ == "__main__":
    files = sorted(glob.glob(os.path.join(MOCK_DIR, "*.json")))
    print(f">>> Found {len(files)} mock event files in {MOCK_DIR}/\n")
    for fp in files:
        process_mock_file(fp)
    print("\n>>> All mock events processed.")