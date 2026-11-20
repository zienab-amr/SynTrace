"""
ingest.py
=========
الكود الوحيد اللي بيحوّل Jira issue -> nodes/edges في Neo4j.
build_graph.py (bulk) و webhook_handler.py (real-time) بيستخدموه بالظبط،
عشان مفيش تضارب بين الـ import الأول والتحديثات الجاية.

مبادئ التصميم:
- مفيش أسامي fields ثابتة: الـ Sprint بيتكتشف من field_meta.json (schema) أو من شكل
  القيمة، وأي field تاني بيتخزن في custom_fields بإسمه الحقيقي.
- كل node ليه uid = "{tenant}:..." و tenant_id (الـ constraints على uid).
- State (ASSIGNED_TO, IN_SPRINT, CHILD_OF, links) بيتبدّل، و Event (ChangeEvent, Comment,
  Worklog) بيتسجّل ويفضل. الـ events بتتكتب حتى لو الـ state قديم (stale).
- حقل مش موجود في الـ payload ما بنلمسوش (الـ webhook ممكن يبعت جزء من الـ fields).
- مفيش email على Person (قرار خصوصية).
"""
import hashlib
import json
import os
import re
from datetime import datetime, timezone
from urllib.parse import urlparse

from adf_parser import parse_adf_description
import field_catalog

DEFAULT_TENANT = os.getenv("TENANT_ID") or None   # no hidden default: a missing tenant must fail, never write to "syntrace"
FIELD_META_PATH = os.getenv("FIELD_META_PATH", "field_meta.json")

# علاقات هيكلية (state بتتبدّل). أي علاقة تانية بين WorkItems = issue link.
STRUCTURAL_REL_TYPES = [
    "ASSIGNED_TO", "REPORTED_BY", "BELONGS_TO", "IN_SPRINT", "CHILD_OF",
    "HAS_COMMENT", "HAS_ATTACHMENT", "HAS_WORKLOG", "HAD_CHANGE",
    "WRITTEN_BY", "LOGGED_BY", "UPLOADED_BY", "CHANGED_BY",
    "FROM_PERSON", "TO_PERSON",
]

# fields بنعالجها صراحةً (مش بتروح custom_fields)
HANDLED_FIELDS = {
    "summary", "description", "issuetype", "status", "priority", "created", "updated",
    "resolutiondate", "duedate", "labels", "components", "project", "assignee",
    "reporter", "parent", "subtasks", "issuelinks", "comment", "worklog", "attachment",
    # Phase 3: explicit handling (previously leaked into custom_fields as strings)
    "resolution", "fixVersions", "versions", "environment", "timetracking",
    "timeoriginalestimate", "timeestimate", "timespent", "creator", "security",
    "statuscategorychangedate",
}
# ضوضاء: الـ raw JSON لسه محتفظ بيها
NOISE_FIELDS = {"watches", "votes", "lastViewed", "progress", "aggregateprogress",
                "workratio", "thumbnail", "aggregatetimespent", "aggregatetimeestimate",
                "aggregatetimeoriginalestimate", "statusCategory", "issuerestriction"}
# Properties a payload may explicitly clear (REMOVE); anything else is rejected.
CLEARABLE_PROPS = {"summary", "created", "updated", "resolutiondate", "duedate",
                   "issuetype", "issuetype_id", "hierarchyLevel", "is_subtask", "status",
                   "status_id", "statusCategory", "priority", "priority_id", "resolution",
                   "resolution_id", "environment", "status_changed_at", "creator_account_id",
                   "security_level", "original_estimate_seconds", "remaining_estimate_seconds",
                   "time_spent_seconds"}


# ==================================================
# Helpers
# ==================================================

def _clean(d):
    return {k: v for k, v in d.items() if v is not None}


def parse_ts(value):
    """Jira timestamp (string أو epoch ms) -> datetime بـ timezone، أو None."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000, tz=timezone.utc)
    s = str(value)
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    try:
        d = datetime.fromisoformat(s.replace("Z", "+00:00"))
        return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def to_utc_iso(value):
    d = parse_ts(value)
    return d.astimezone(timezone.utc).isoformat() if d else None


def is_stale(existing_updated, incoming_updated):
    """Conservatively reject state with no provable ordering against existing state."""
    old, new = parse_ts(existing_updated), parse_ts(incoming_updated)
    if old is not None and new is None:
        return True
    if old is None and new is None:
        return True
    if old is None:
        return False
    return new <= old


def _int_or_none(v):
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return None


def compare_versions(existing_updated, existing_cid, incoming_updated, incoming_cid,
                     event_time=None, existing_fp=None, incoming_fp=None,
                     existing_fp_mode=None, incoming_fp_mode=None):
    """Order an incoming issue state against the stored one.

    Returns "newer" | "older" | "duplicate" | "ambiguous". Evidence, strongest first:
      1. issue `updated` (ms resolution) when both parse and differ;
      2. Jira changelog history id (monotonic per issue) when `updated` ties or is missing;
      3. content fingerprint for a tie in the same payload mode;
      4. webhook `timestamp` only as PROOF OF OLDER (event fired before the stored state);
         never as proof of newer, because delivery time says nothing about issue state.
    "ambiguous" means no ordering can be proven: callers must not overwrite state.
    """
    old, new = parse_ts(existing_updated), parse_ts(incoming_updated)
    e_cid, i_cid = _int_or_none(existing_cid), _int_or_none(incoming_cid)
    if old is not None and new is not None:
        if new > old:
            return "newer"
        if new < old:
            return "older"
    elif old is None and new is not None:
        return "newer"          # nothing trustworthy stored to protect
    # tie, or incoming has no usable `updated`
    if i_cid is not None and e_cid is not None:
        if i_cid > e_cid:
            return "newer"
        return "duplicate" if i_cid == e_cid else "older"
    if new is None:
        ev = parse_ts(event_time)
        if old is not None and ev is not None and ev < old:
            return "older"
        return "ambiguous"
    # equal `updated`, no changelog ids to separate them
    if (existing_fp and incoming_fp and existing_fp_mode == incoming_fp_mode
            and existing_fp != incoming_fp):
        return "ambiguous"      # same timestamp, same payload kind, different content
    return "duplicate"


def state_fingerprint(model):
    """Stable hash of the state a payload would write (used only to break `updated` ties)."""
    body = {"p": model["props"], "c": model.get("clear_props"),
            "a": (model.get("assignee") or {}).get("uid") if "assignee" in model else "-",
            "r": (model.get("reporter") or {}).get("uid") if "reporter" in model else "-",
            "s": [x["uid"] for x in model["sprints"]] if "sprints" in model else "-",
            "pa": model.get("parent", "-"), "st": model.get("subtasks", "-"),
            "l": sorted(model["links"]) if "links" in model else "-"}
    return hashlib.sha1(json.dumps(body, sort_keys=True, default=str).encode()).hexdigest()


def rel_type_of(name):
    """اسم الـ link (outward) -> relationship type آمن للـ Cypher."""
    r = re.sub(r"[^A-Z0-9_]", "_", (name or "").upper().replace(" ", "_"))
    if not r.strip("_"):
        return "LINKED_TO"
    return r if re.match(r"[A-Z_]", r) else f"LINK_{r}"


def media_kind(mime):
    mime = (mime or "").lower()
    for prefix, kind in (("image/", "image"), ("video/", "video"), ("audio/", "audio")):
        if mime.startswith(prefix):
            return kind
    if mime == "application/pdf" or mime.startswith("text/"):
        return "document"
    return "other"


def site_url(issue):
    parsed = urlparse(issue.get("self") or "")
    if parsed.scheme and parsed.netloc:
        return f"{parsed.scheme}://{parsed.netloc}"
    return os.getenv("JIRA_BASE_URL", "").rstrip("/")


def jira_site_id(issue=None, site_id=None):
    """Stable site/instance scope; configure JIRA_SITE_ID when hostname can change."""
    value = site_id or os.getenv("JIRA_SITE_ID")
    if not value and issue:
        value = urlparse(issue.get("self") or "").hostname
    if not value:
        value = urlparse(os.getenv("JIRA_BASE_URL", "")).hostname
    if not value:
        raise ValueError("Jira site identity unavailable; set JIRA_SITE_ID or provide issue.self")
    return re.sub(r"[^A-Za-z0-9_.-]", "_", str(value).strip().lower())


def workitem_uid(tenant_id, site_id, jira_id):
    if jira_id is None or str(jira_id).strip() == "":
        raise ValueError("A Jira issue id is required for stable WorkItem identity")
    return f"{tenant_id}:site:{site_id}:issue:{jira_id}"


def require_tenant(tenant_id):
    if tenant_id is None or not str(tenant_id).strip():
        raise ValueError("tenant_id is required (there is no default tenant)")
    return tenant_id


def project_key_of(key):
    return key.rsplit("-", 1)[0]


# ==================================================
# ADF -> text (مع أسطر جديدة، للـ embeddings والكومنتات)
# ==================================================

_INLINE_BLOCKS = {"paragraph", "heading", "codeBlock", "taskItem", "decisionItem"}
_LISTS = {"bulletList", "orderedList", "taskList", "decisionList"}


def adf_to_text(node):
    if node is None:
        return ""
    if isinstance(node, str):
        return node
    t = node.get("type")
    attrs = node.get("attrs") or {}
    if t == "text":
        return node.get("text", "")
    if t == "hardBreak":
        return "\n"
    if t == "mention":
        return attrs.get("text", "")
    if t == "emoji":
        return attrs.get("text") or attrs.get("shortName", "")
    if t in ("inlineCard", "blockCard", "embedCard"):
        return attrs.get("url", "")
    children = [adf_to_text(c) for c in node.get("content") or []]
    if t in _INLINE_BLOCKS:
        return "".join(children)
    if t in _LISTS:
        return "\n".join(f"- {c.strip()}" for c in children if c.strip())
    if t == "tableRow":
        return " | ".join(c.strip() for c in children if c.strip())
    if t in ("tableCell", "tableHeader"):
        return " ".join(c.strip() for c in children if c.strip())
    return "\n".join(c for c in children if c.strip())


def simplify(v):
    """قيمة field غريبة -> قيمة بسيطة قابلة للتخزين كـ JSON، أو None لو فاضية."""
    if v is None:
        return None
    if isinstance(v, str):
        return v if v.strip() else None
    if isinstance(v, (int, float, bool)):
        return v
    if isinstance(v, list):
        out = [simplify(x) for x in v]
        out = [x for x in out if x is not None]
        return out or None
    if isinstance(v, dict):
        if v.get("type") == "doc":
            return adf_to_text(v).strip() or None
        for k in ("displayName", "name", "value"):
            if v.get(k) is not None:
                return v[k]
        scalars = {k: x for k, x in v.items()
                   if isinstance(x, (str, int, float, bool)) and k not in ("self", "id", "iconUrl")}
        return scalars or None
    return None


# ==================================================
# Field metadata (من /rest/api/3/field، بيتحفظ بـ the backend import)
# ==================================================

def load_field_meta(path=None):
    try:
        with open(path or FIELD_META_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


FIELD_META = load_field_meta()


def refresh_field_meta(field_list, path=None, persist=True):
    """Replace the in-process field catalog from a /rest/api/3/field response (in place, so
    existing references stay valid) and optionally persist it. Returns the field count."""
    meta = field_catalog.meta_from_api(field_list)
    if not meta:
        return 0                      # never wipe a good catalog with an empty answer
    FIELD_META.clear()
    FIELD_META.update(meta)
    if persist:
        field_catalog.save_meta(meta, path or FIELD_META_PATH)
    return len(meta)


def is_sprint_field(fid, value, meta):
    schema_custom = (meta.get(fid) or {}).get("schema_custom") or ""
    if schema_custom.endswith("gh-sprint"):
        return True
    return (isinstance(value, list) and bool(value)
            and all(isinstance(x, dict) and {"id", "name", "state"} <= set(x) for x in value))


# ==================================================
# Normalizers (pure: من غير Neo4j، عشان تتختبر أوفلاين)
# ==================================================

def normalize_person(obj, tenant_id):
    if not isinstance(obj, dict) or not obj.get("accountId"):
        return None
    return {
        "uid": f"{tenant_id}:person:{obj['accountId']}",
        "props": _clean({"tenant_id": tenant_id, "accountId": obj["accountId"],
                         "displayName": obj.get("displayName"),
                         "accountType": obj.get("accountType"), "active": obj.get("active")}),
    }


def _text_of(body):
    return adf_to_text(body).strip() if isinstance(body, dict) else (body or "")


def normalize_comment(c, tenant_id, issue_key, project_key, site_id=None):
    cid = str(c["id"])
    site = site_id or jira_site_id()
    return {
        "uid": f"{tenant_id}:site:{site}:comment:{cid}",
        "props": _clean({"id": cid, "text": _text_of(c.get("body")),
                         "created": c.get("created"), "updated": c.get("updated"),
                         "tenant_id": tenant_id, "jira_site_id": site, "issue_key": issue_key,
                         "project_key": project_key}),
        "author": normalize_person(c.get("author"), tenant_id),
    }


def normalize_worklog(w, tenant_id, issue_key=None, project_key=None, site_id=None):
    wid = str(w["id"])
    site = site_id or jira_site_id()
    return {
        "uid": f"{tenant_id}:site:{site}:worklog:{wid}",
        "props": _clean({"id": wid, "timeSpent": w.get("timeSpent"),
                         "timeSpentSeconds": w.get("timeSpentSeconds"),
                         "started": w.get("started"), "created": w.get("created"),
                         "updated": w.get("updated"), "text": _text_of(w.get("comment")),
                         "issue_id": str(w["issueId"]) if w.get("issueId") is not None else None,
                         "tenant_id": tenant_id, "jira_site_id": site, "issue_key": issue_key,
                         "project_key": project_key}),
        "author": normalize_person(w.get("author"), tenant_id),
    }


def normalize_attachment(a, tenant_id, issue_key, project_key, site_id=None):
    aid = str(a["id"])
    site = site_id or jira_site_id()
    return {
        "uid": f"{tenant_id}:site:{site}:attachment:{aid}",
        "props": _clean({"id": aid, "filename": a.get("filename"),
                         "mimeType": a.get("mimeType"), "size": a.get("size"),
                         "created": a.get("created"), "content_url": a.get("content"),
                         "kind": media_kind(a.get("mimeType")),
                         "tenant_id": tenant_id, "jira_site_id": site, "issue_key": issue_key,
                         "project_key": project_key}),
        "author": normalize_person(a.get("author"), tenant_id),
    }


def normalize_sprint(s, tenant_id, site_id=None):
    site = site_id or jira_site_id()
    return {
        "uid": f"{tenant_id}:site:{site}:sprint:{s['id']}",
        "props": _clean({"id": s["id"], "name": s.get("name"), "state": s.get("state"),
                         "goal": s.get("goal"), "startDate": s.get("startDate"),
                         "endDate": s.get("endDate"), "completeDate": s.get("completeDate"),
                         "boardId": s.get("boardId", s.get("originBoardId")),
                         "tenant_id": tenant_id, "jira_site_id": site}),
    }


def normalize_project(p, tenant_id, site_id=None):
    site = jira_site_id(p, site_id)
    return {
        "uid": f"{tenant_id}:site:{site}:project:{p['key']}",
        "props": _clean({"tenant_id": tenant_id, "jira_site_id": site,
                         "key": p["key"], "name": p.get("name"),
                         "projectTypeKey": p.get("projectTypeKey"),
                         "jira_id": str(p["id"]) if p.get("id") not in (None, "") else None}),
    }


def normalize_changes(histories, tenant_id, issue_key, project_key, site_id=None, issue_id=None):
    """changelog histories -> ChangeEvent list (تاريخ التغييرات، بيفضل للأبد)."""
    site = site_id or jira_site_id()
    out = []
    for h in histories or []:
        raw_created = h.get("created")
        for i, item in enumerate(h.get("items") or []):
            field = item.get("field")
            hid = h.get("id")
            if hid is None:
                sig = f"{issue_id or issue_key}|{raw_created}|{field}|{item.get('from')}|{item.get('to')}"
                hid = hashlib.sha1(sig.encode("utf-8")).hexdigest()[:16]
            ev = {
                "uid": f"{tenant_id}:site:{site}:change:{issue_id or issue_key}:{hid}:{i}",
                "props": _clean({
                    "tenant_id": tenant_id, "jira_site_id": site,
                    "issue_id": str(issue_id) if issue_id is not None else None,
                    "issue_key": issue_key, "project_key": project_key,
                    "field": field, "fieldtype": item.get("fieldtype"),
                    "from_id": item.get("from"), "from_name": item.get("fromString"),
                    "to_id": item.get("to"), "to_name": item.get("toString"),
                    "changed_at": to_utc_iso(raw_created),
                    "author": (h.get("author") or {}).get("displayName"),
                }),
                "author": normalize_person(h.get("author"), tenant_id),
                "from_person": None,
                "to_person": None,
            }
            if field == "assignee":
                for side, idk, namek in (("from_person", "from", "fromString"),
                                         ("to_person", "to", "toString")):
                    if item.get(idk):
                        ev[side] = normalize_person(
                            {"accountId": item[idk], "displayName": item.get(namek)}, tenant_id)
            out.append(ev)
    return out


def _histories(issue, changelog, actor, event_time):
    if changelog is None:
        return (issue.get("changelog") or {}).get("histories") or []
    if "histories" in changelog:
        return changelog["histories"]
    if "items" in changelog:  # شكل الـ webhook: {"id":..., "items":[...]}
        return [{"id": changelog.get("id"), "created": event_time,
                 "author": actor, "items": changelog["items"]}]
    return []


def normalize_issue(issue, tenant_id=DEFAULT_TENANT, field_meta=None,
                    changelog=None, actor=None, event_time=None,
                    payload_mode="partial", site_id=None, browse_base=None):
    if payload_mode not in ("full", "partial"):
        raise ValueError("payload_mode must be 'full' or 'partial'")
    tenant_id = require_tenant(tenant_id)
    meta = FIELD_META if field_meta is None else field_meta
    names = issue.get("names") or {}
    fields = issue.get("fields") or {}
    key = issue["key"]
    jira_id = str(issue.get("id") or "").strip()
    if not jira_id:
        raise ValueError(f"Issue {key} has no Jira id; refusing unstable identity")
    site = jira_site_id(issue, site_id)
    project_key = (fields.get("project") or {}).get("key") or project_key_of(key)

    props = {"key": key, "tenant_id": tenant_id, "jira_site_id": site,
             "project_key": project_key, "url": f"{(browse_base or site_url(issue)).rstrip('/')}/browse/{key}",
             "jira_id": jira_id}
    clear_props = []
    for p in ("summary", "created", "updated", "resolutiondate", "duedate"):
        if p in fields and fields[p] is not None:
            props[p] = fields[p]
        elif p in fields or payload_mode == "full":
            clear_props.append(p)
    if "labels" in fields or payload_mode == "full":
        props["labels"] = fields.get("labels") or []
    if "components" in fields or payload_mode == "full":
        props["components"] = [c["name"] for c in fields.get("components") or [] if c.get("name")]
    if fields.get("issuetype"):
        it = fields["issuetype"]
        props["issuetype"] = it.get("name")
        if it.get("id") is not None:
            props["issuetype_id"] = str(it["id"])
        props["hierarchyLevel"] = it.get("hierarchyLevel")
        props["is_subtask"] = bool(it.get("subtask"))
    elif "issuetype" in fields or payload_mode == "full":
        clear_props.extend(("issuetype", "issuetype_id", "hierarchyLevel", "is_subtask"))
    if fields.get("status"):
        st = fields["status"]
        props["status"] = st.get("name")
        if st.get("id") is not None:
            props["status_id"] = str(st["id"])
        props["statusCategory"] = (st.get("statusCategory") or {}).get("key")
    elif "status" in fields or payload_mode == "full":
        clear_props.extend(("status", "status_id", "statusCategory"))
    if fields.get("priority"):
        props["priority"] = fields["priority"].get("name")
        if fields["priority"].get("id") is not None:
            props["priority_id"] = str(fields["priority"]["id"])
    elif "priority" in fields or payload_mode == "full":
        clear_props.extend(("priority", "priority_id"))

    # resolution, versions, environment, estimates, security, creator (Phase 3)
    if fields.get("resolution"):
        props["resolution"] = fields["resolution"].get("name")
        if fields["resolution"].get("id") is not None:
            props["resolution_id"] = str(fields["resolution"]["id"])
    elif "resolution" in fields or payload_mode == "full":
        clear_props.extend(("resolution", "resolution_id"))
    for src, dst in (("fixVersions", "fix_versions"), ("versions", "affects_versions")):
        if src in fields or payload_mode == "full":
            props[dst] = [v["name"] for v in fields.get(src) or [] if isinstance(v, dict) and v.get("name")]
    if "environment" in fields or payload_mode == "full":
        env = fields.get("environment")
        env = adf_to_text(env).strip() if isinstance(env, dict) else (env or "")
        if env:
            props["environment"] = env
        else:
            clear_props.append("environment")
    tt = fields.get("timetracking") if isinstance(fields.get("timetracking"), dict) else {}
    for dst, nested, top in (("original_estimate_seconds", "originalEstimateSeconds", "timeoriginalestimate"),
                             ("remaining_estimate_seconds", "remainingEstimateSeconds", "timeestimate"),
                             ("time_spent_seconds", "timeSpentSeconds", "timespent")):
        present = nested in tt or top in fields or "timetracking" in fields
        val = tt.get(nested, fields.get(top))
        if isinstance(val, (int, float)) and not isinstance(val, bool):
            props[dst] = int(val)
        elif present or payload_mode == "full":
            clear_props.append(dst)
    if fields.get("security"):
        props["security_level"] = fields["security"].get("name")
    elif "security" in fields or payload_mode == "full":
        clear_props.append("security_level")
    if isinstance(fields.get("creator"), dict) and fields["creator"].get("accountId"):
        props["creator_account_id"] = fields["creator"]["accountId"]
    elif "creator" in fields or payload_mode == "full":
        clear_props.append("creator_account_id")
    if fields.get("statuscategorychangedate"):
        iso = to_utc_iso(fields["statuscategorychangedate"])
        if iso:
            props["status_changed_at"] = iso
    elif "statuscategorychangedate" in fields:
        clear_props.append("status_changed_at")
    if "description" in fields or payload_mode == "full":
        desc = fields.get("description")
        if isinstance(desc, dict):
            parsed = parse_adf_description(desc)
            props["description_text"] = adf_to_text(desc).strip()
        else:
            parsed = {"intro": desc or "", "sections": {}}
            props["description_text"] = desc or ""
        props["description_intro"] = parsed["intro"]
        props["description_sections"] = json.dumps(parsed["sections"], ensure_ascii=False)

    # sprints + every other field: discovered dynamically (field_catalog), type-preserving.
    sprint_field_ids = [fid for fid, info in meta.items()
                        if ((info or {}).get("schema_custom") or "").endswith("gh-sprint")]
    typed, raw_by_id, defs, sprint_values, warnings = field_catalog.normalize_extra_fields(
        fields, names, meta, HANDLED_FIELDS, NOISE_FIELDS,
        {"adf_to_text": adf_to_text, "to_utc_iso": to_utc_iso})
    sprints = None
    if sprint_values is not None:
        sprints = [normalize_sprint(x, tenant_id, site) for x in sprint_values
                   if isinstance(x, dict) and x.get("id") is not None]
    elif payload_mode == "full" and sprint_field_ids:
        sprints = []
    if typed or raw_by_id or any(k.startswith("customfield_") for k in fields) or payload_mode == "full":
        props["custom_fields"] = json.dumps(typed, ensure_ascii=False, default=str)
        props["custom_fields_raw"] = json.dumps(raw_by_id, ensure_ascii=False, default=str)
        props["custom_field_defs"] = json.dumps(defs, ensure_ascii=False, default=str)
    warnings = warnings + list((issue.get("_ingest") or {}).get("incomplete") or [])
    if "_ingest" in issue or warnings or payload_mode == "full":
        props["ingest_warnings"] = warnings

    model = {
        "uid": workitem_uid(tenant_id, site, jira_id),
        "legacy_uid": f"{tenant_id}:{key}", "key": key, "tenant_id": tenant_id,
        "site_id": site, "jira_id": jira_id, "payload_mode": payload_mode,
        "clear_props": sorted(set(clear_props)), "props": props,
        "project": normalize_project(
            {**(fields.get("project") or {}), "key": project_key}, tenant_id, site),
    }
    if "assignee" in fields or payload_mode == "full":
        model["assignee"] = normalize_person(fields.get("assignee"), tenant_id)
    if "reporter" in fields or payload_mode == "full":
        model["reporter"] = normalize_person(fields.get("reporter"), tenant_id)
    if sprints is not None:
        model["sprints"] = sprints
    if "parent" in fields or payload_mode == "full":
        p = fields.get("parent")
        model["parent"] = p["key"] if p and p.get("key") else None
    if "subtasks" in fields or payload_mode == "full":
        model["subtasks"] = [s["key"] for s in fields.get("subtasks") or [] if s.get("key")]
    if "issuelinks" in fields or payload_mode == "full":
        links = []
        for link in fields.get("issuelinks") or []:
            rel = rel_type_of((link.get("type") or {}).get("outward"))
            if "outwardIssue" in link:
                links.append((rel, key, link["outwardIssue"]["key"]))
            elif "inwardIssue" in link:
                links.append((rel, link["inwardIssue"]["key"], key))
        model["links"] = links

    model["comments"] = [normalize_comment(c, tenant_id, key, project_key, site)
                         for c in (fields.get("comment") or {}).get("comments") or []]
    model["worklogs"] = [normalize_worklog(w, tenant_id, key, project_key, site)
                        for w in (fields.get("worklog") or {}).get("worklogs") or []]
    model["attachments"] = [normalize_attachment(a, tenant_id, key, project_key, site)
                            for a in fields.get("attachment") or []]
    histories = _histories(issue, changelog, actor, event_time)
    model["changes"] = normalize_changes(histories, tenant_id, key, project_key, site, jira_id)
    ids = [_int_or_none(h.get("id")) for h in histories]
    ids = [i for i in ids if i is not None]
    model["changelog_max_id"] = max(ids) if ids else None
    model["fingerprint"] = state_fingerprint(model)
    return model


# ==================================================
# Writers (Cypher). كل الـ labels/relationships جاية من constants جوه الكود فقط.
# ==================================================

def _merge_person(tx, person, create_only=False):
    verb = "ON CREATE SET p += $props" if create_only else "SET p += $props"
    tx.run(f"MERGE (p:Person {{uid: $uid}}) {verb}", uid=person["uid"], props=person["props"])


def _edge(tx, a_label, a_uid, rel, b_label, b_uid):
    tx.run(
        f"MATCH (a:{a_label} {{uid: $a}}) MATCH (b:{b_label} {{uid: $b}}) "
        f"MERGE (a)-[:{rel}]->(b)", a=a_uid, b=b_uid)


def _replace_out_edges(tx, uid, rel, label="WorkItem"):
    if label not in {"WorkItem", "Comment", "Worklog", "Attachment", "ChangeEvent"}:
        raise ValueError(f"unsupported relationship owner label: {label}")
    tx.run(f"MATCH (w:{label} {{uid: $uid}}) OPTIONAL MATCH (w)-[r:{rel}]->() DELETE r", uid=uid)


def _merge_stub(tx, tenant_id, key, site_id=None):
    """Resolve an existing current/alias key, otherwise create a sparse site-scoped stub."""
    site = site_id or jira_site_id()
    row = tx.run(
        "MATCH (x:WorkItem {tenant_id: $tenant}) WHERE x.jira_site_id = $site "
        "AND (x.key = $key OR $key IN coalesce(x.key_aliases, [])) "
        "RETURN x.uid AS uid LIMIT 1", tenant=tenant_id, site=site, key=key).single()
    if row:
        return row["uid"]
    legacy_rows = list(tx.run(
        "MATCH (x:WorkItem {uid: $uid}) RETURN x.uid AS uid, x.jira_site_id AS site",
        uid=f"{tenant_id}:{key}"))
    if len(legacy_rows) > 1:
        raise IdentityConflictError(f"Legacy key {key} is ambiguous")
    if legacy_rows and legacy_rows[0].get("site") in (None, site):
        uid = legacy_rows[0]["uid"]
        tx.run("MATCH (x:WorkItem {uid: $uid}) SET x.jira_site_id = $site", uid=uid, site=site)
        return uid
    uid = f"{tenant_id}:site:{site}:stub:{key}"
    tx.run("MERGE (x:WorkItem {uid: $uid}) "
           "ON CREATE SET x.key = $key, x.tenant_id = $tenant, x.jira_site_id = $site, "
           "x.project_key = $project", uid=uid, key=key, tenant=tenant_id,
           site=site, project=project_key_of(key))
    return uid


class IdentityConflictError(RuntimeError):
    """Existing graph nodes conflict with stable Jira identity; operator review is required."""


def _absorb_sparse_stub(tx, stub_uid, stable_uid):
    """Rewire and then remove only an incomplete key-reference stub."""
    for direction, query in (
        ("out", "MATCH (s:WorkItem {uid: $uid})-[r]->(o) "
                 "RETURN type(r) AS typ, properties(r) AS props, o.uid AS other_uid"),
        ("in", "MATCH (o)-[r]->(s:WorkItem {uid: $uid}) "
                "RETURN type(r) AS typ, properties(r) AS props, o.uid AS other_uid"),
    ):
        for edge in tx.run(query, uid=stub_uid):
            typ = edge["typ"]
            if not re.fullmatch(r"[A-Z][A-Z0-9_]*", typ):
                raise IdentityConflictError(f"Unsafe legacy relationship type {typ!r}; stub retained")
            other = edge["other_uid"]
            if other == stable_uid:
                continue
            if direction == "out":
                cypher = (f"MATCH (a {{uid: $stable}}) MATCH (b {{uid: $other}}) "
                          f"MERGE (a)-[r:{typ}]->(b) "
                          "WITH r, coalesce(r.evidence, []) AS previous_evidence, "
                          "coalesce(r.source_issue_uids, []) AS previous_sources "
                          "SET r += $props "
                          "SET r.evidence = reduce(acc = previous_evidence, x IN coalesce($props.evidence, []) "
                          "| CASE WHEN x IN acc THEN acc ELSE acc + [x] END), "
                          "r.source_issue_uids = reduce(acc = previous_sources, x IN coalesce($props.source_issue_uids, []) "
                          "| CASE WHEN x IN acc THEN acc ELSE acc + [x] END)")
            else:
                cypher = (f"MATCH (a {{uid: $other}}) MATCH (b {{uid: $stable}}) "
                          f"MERGE (a)-[r:{typ}]->(b) "
                          "WITH r, coalesce(r.evidence, []) AS previous_evidence, "
                          "coalesce(r.source_issue_uids, []) AS previous_sources "
                          "SET r += $props "
                          "SET r.evidence = reduce(acc = previous_evidence, x IN coalesce($props.evidence, []) "
                          "| CASE WHEN x IN acc THEN acc ELSE acc + [x] END), "
                          "r.source_issue_uids = reduce(acc = previous_sources, x IN coalesce($props.source_issue_uids, []) "
                          "| CASE WHEN x IN acc THEN acc ELSE acc + [x] END)")
            tx.run(cypher, stable=stable_uid, other=other, props=edge["props"] or {})
    tx.run("MATCH (s:WorkItem {uid: $uid}) DETACH DELETE s", uid=stub_uid)


def adopt_workitem_identity(tx, model):
    """Adopt a single legacy node in place; only sparse reference stubs may be absorbed."""
    stable = tx.run("MATCH (w:WorkItem {uid: $uid}) RETURN w.uid AS uid",
                    uid=model["uid"]).single()
    candidates = list(tx.run(
        "MATCH (w:WorkItem {tenant_id: $tenant, jira_id: $jira_id}) "
        "WHERE w.jira_site_id = $site OR w.jira_site_id IS NULL "
        "RETURN w.uid AS uid, w.key AS key, w.jira_site_id AS site, w.summary AS summary",
        tenant=model["tenant_id"], jira_id=model["jira_id"], site=model["site_id"]))
    candidate_uids = {r["uid"] for r in candidates if r.get("uid")}
    if len(candidate_uids) > 1 or (stable and any(u != model["uid"] for u in candidate_uids)):
        raise IdentityConflictError(
            f"Multiple WorkItems match Jira identity {model['site_id']}/{model['jira_id']}: "
            f"{sorted(candidate_uids)}; no automatic merge performed")

    legacy = tx.run("MATCH (w:WorkItem {uid: $uid}) "
                    "RETURN w.uid AS uid, w.jira_id AS jira_id, w.key AS key, "
                    "w.jira_site_id AS site, w.summary AS summary",
                    uid=model["legacy_uid"]).single()
    stub = tx.run(
        "MATCH (w:WorkItem {tenant_id: $tenant, jira_site_id: $site, key: $key}) "
        "WHERE w.summary IS NULL RETURN w.uid AS uid, w.jira_id AS jira_id, w.key AS key, "
        "w.jira_site_id AS site, w.summary AS summary",
        tenant=model["tenant_id"], site=model["site_id"], key=model["key"]).single()
    if legacy and stub and legacy.get("uid") != stub.get("uid"):
        raise IdentityConflictError(f"Multiple legacy/stub identities exist for {model['key']}")
    # Prefer the node already carrying this Jira ID (including an old-key node).
    candidate = candidates[0] if candidates else None
    candidate_original_uid = candidate.get("uid") if candidate else None
    if candidate and candidate.get("uid") != model["uid"]:
        if stable:
            raise IdentityConflictError("Stable and legacy nodes share the same Jira identity")
        tx.run("MATCH (w:WorkItem {uid: $old_uid}) "
               "SET w.uid = $uid, w.jira_site_id = $site, w.jira_id = $jira_id",
               old_uid=candidate["uid"], uid=model["uid"],
               site=model["site_id"], jira_id=model["jira_id"])
        stable = {"uid": model["uid"]}

    # Existing target-key stubs can have useful links. Rewire them before removal.
    for sparse in (legacy, stub):
        if (not sparse or sparse.get("uid") == model["uid"]
                or sparse.get("uid") == candidate_original_uid):
            continue
        if sparse.get("jira_id") and str(sparse["jira_id"]) != model["jira_id"]:
            raise IdentityConflictError(
                f"Legacy key {model['key']} belongs to Jira id {sparse['jira_id']}, "
                f"not {model['jira_id']}; no overwrite performed")
        if sparse.get("site") not in (None, model["site_id"]):
            raise IdentityConflictError(
                f"Legacy key {model['key']} belongs to another Jira site; manual review required")
        if sparse.get("summary") is not None:
            raise IdentityConflictError(
                f"Complete WorkItem {sparse.get('uid')} conflicts with identity for {model['key']}")
        if not stable:
            tx.run("MATCH (w:WorkItem {uid: $old_uid}) "
                   "SET w.uid = $uid, w.jira_site_id = $site, w.jira_id = $jira_id",
                   old_uid=sparse["uid"], uid=model["uid"],
                   site=model["site_id"], jira_id=model["jira_id"])
            stable = {"uid": model["uid"]}
        elif sparse["uid"] != model["uid"]:
            _absorb_sparse_stub(tx, sparse["uid"], model["uid"])


def adopt_project_identity(tx, project):
    legacy_uid = f"{project['props']['tenant_id']}:project:{project['props']['key']}"
    stable = tx.run("MATCH (p:Project {uid: $uid}) RETURN p.uid AS uid",
                    uid=project["uid"]).single()
    legacy = tx.run("MATCH (p:Project {uid: $uid}) RETURN p.uid AS uid",
                    uid=legacy_uid).single()
    if legacy and legacy.get("uid") != project["uid"]:
        if stable:
            raise IdentityConflictError(
                f"Both stable and legacy Project nodes exist for {project['props']['key']}; "
                "manual reconciliation required")
        tx.run("MATCH (p:Project {uid: $old_uid}) SET p.uid = $uid, "
               "p.jira_site_id = $site", old_uid=legacy_uid, uid=project["uid"],
               site=project["props"]["jira_site_id"])
    pid = project["props"].get("jira_id")
    if pid:
        # A Jira project id is stable while its key can be changed: rename in place and
        # keep the previous key as an alias instead of creating a second Project node.
        other = tx.run(
            "MATCH (p:Project {tenant_id: $t, jira_site_id: $s, jira_id: $id}) "
            "WHERE p.uid <> $uid RETURN p.uid AS uid, p.key AS key",
            t=project["props"]["tenant_id"], s=project["props"]["jira_site_id"],
            id=pid, uid=project["uid"]).single()
        if other:
            if stable:
                raise IdentityConflictError(
                    f"Project id {pid} exists under two keys; manual reconciliation required")
            tx.run("MATCH (p:Project {uid: $old}) SET p.uid = $uid, p.key = $key, "
                   "p.key_aliases = [k IN coalesce(p.key_aliases, []) + [$old_key] "
                   "WHERE k IS NOT NULL AND k <> $key]",
                   old=other["uid"], uid=project["uid"], key=project["props"]["key"],
                   old_key=other["key"])
            tx.run("MATCH (w:WorkItem {tenant_id: $t, jira_site_id: $s, project_key: $old_key}) "
                   "SET w.project_key = $key", t=project["props"]["tenant_id"],
                   s=project["props"]["jira_site_id"], old_key=other["key"],
                   key=project["props"]["key"])


def resolve_project_key(tx, tenant_id, site, project_id):
    row = tx.run("MATCH (p:Project {tenant_id: $t, jira_site_id: $s, jira_id: $id}) "
                 "RETURN p.key AS key", t=tenant_id, s=site, id=str(project_id)).single()
    return row["key"] if row else None


def delete_project(tx, project_key, tenant_id, site_id=None, deletion_time=None,
                   project_id=None, soft=False):
    """Hard-delete a project and every issue currently represented under it; no per-issue
    event is required. Nothing is kept: if the project comes back it is simply stored again.
    Returns the number of issues removed.

    Either key or project_id may be missing (internal {type,id} notices carry only an id);
    the key is resolved through the stored Project.jira_id. If neither resolves, nothing in
    the graph belongs to this project, so there is nothing to do."""
    site = jira_site_id({"self": os.getenv("JIRA_BASE_URL", "")}, site_id)
    pid = str(project_id) if project_id not in (None, "") else None
    if not project_key and pid:
        project_key = resolve_project_key(tx, tenant_id, site, pid)
    if not project_key:
        return 0
    keys = [r["key"] for r in tx.run(
        "MATCH (w:WorkItem {tenant_id: $tenant, jira_site_id: $site, project_key: $key}) "
        "RETURN w.key AS key", tenant=tenant_id, site=site, key=project_key)]
    for key in keys:
        delete_issue(tx, key, tenant_id, site_id=site, deletion_time=deletion_time)
    tx.run("MATCH (p:Project {tenant_id: $tenant, jira_site_id: $site, key: $key}) "
           "DETACH DELETE p", tenant=tenant_id, site=site, key=project_key)
    return len(keys)


def _person_edge(tx, a_label, a_uid, rel, person, create_only=False):
    if person:
        _merge_person(tx, person, create_only)
        _edge(tx, a_label, a_uid, rel, "Person", person["uid"])


def write_issue_state(tx, m):
    uid, tenant = m["uid"], m["tenant_id"]
    tx.run(
        "MERGE (w:WorkItem {uid: $uid}) WITH w, w.key AS prior_key "
        "SET w += $props "
        "SET w.key_aliases = [k IN coalesce(w.key_aliases, []) + [prior_key, $props.key] "
        "WHERE k IS NOT NULL AND k <> $props.key]",
        uid=uid, props=m["props"])
    # version bookkeeping: changelog id only ever moves forward; a successful state write
    # also clears any earlier "needs reconciliation" flag.
    tx.run("MATCH (w:WorkItem {uid: $uid}) "
           "SET w.last_changelog_id = CASE WHEN $cid IS NULL THEN w.last_changelog_id "
           "WHEN w.last_changelog_id IS NULL OR $cid > w.last_changelog_id THEN $cid "
           "ELSE w.last_changelog_id END, "
           "w.state_fp = $fp, w.state_fp_mode = $mode "
           "REMOVE w.reconcile_needed, w.reconcile_reason, w.reconcile_flagged_at, "
           "w.source_visibility, w.source_visibility_checked_at",
           uid=uid, cid=m.get("changelog_max_id"), fp=m.get("fingerprint"),
           mode=m.get("payload_mode"))
    for prop in m.get("clear_props", []):
        if prop not in CLEARABLE_PROPS:
            raise ValueError(f"Unsupported property clear request: {prop}")
        tx.run(f"MATCH (w:WorkItem {{uid: $uid}}) REMOVE w.{prop}", uid=uid)

    _replace_out_edges(tx, uid, "BELONGS_TO")
    adopt_project_identity(tx, m["project"])
    tx.run("MERGE (pr:Project {uid: $puid}) SET pr += $pprops",
           puid=m["project"]["uid"], pprops=m["project"]["props"])
    _edge(tx, "WorkItem", uid, "BELONGS_TO", "Project", m["project"]["uid"])

    for field, rel in (("assignee", "ASSIGNED_TO"), ("reporter", "REPORTED_BY")):
        if field in m:  # غياب الـ field = ما نلمسش؛ null = unassigned (مفيش edge)
            _replace_out_edges(tx, uid, rel)
            _person_edge(tx, "WorkItem", uid, rel, m[field])

    if "sprints" in m:
        _replace_out_edges(tx, uid, "IN_SPRINT")
        for s in m["sprints"]:
            tx.run("MERGE (s:Sprint {uid: $suid}) SET s += $props", suid=s["uid"], props=s["props"])
            _edge(tx, "WorkItem", uid, "IN_SPRINT", "Sprint", s["uid"])

    if "parent" in m:
        _replace_out_edges(tx, uid, "CHILD_OF")
        if m["parent"]:
            parent_uid = _merge_stub(tx, tenant, m["parent"], m["site_id"])
            _edge(tx, "WorkItem", uid, "CHILD_OF", "WorkItem", parent_uid)
    if "subtasks" in m:
        tx.run("MATCH (s:WorkItem)-[r:CHILD_OF]->(p:WorkItem {uid: $uid}) "
               "WHERE coalesce(s.is_subtask, false) = true AND NOT s.key IN $subtasks DELETE r", uid=uid, subtasks=m["subtasks"])
    for sub in m.get("subtasks", []):
        child_uid = _merge_stub(tx, tenant, sub, m["site_id"])
        _edge(tx, "WorkItem", child_uid, "CHILD_OF", "WorkItem", uid)

    if "links" in m:
        tx.run("MATCH (w:WorkItem {uid: $uid})-[r]-(:WorkItem) "
               "WHERE NOT type(r) IN $structural AND $uid IN coalesce(r.source_issue_uids, []) "
               "SET r.source_issue_uids = [x IN r.source_issue_uids WHERE x <> $uid] "
               "WITH r WHERE size(r.source_issue_uids) = 0 AND size(coalesce(r.evidence, [])) = 0 DELETE r",
               uid=uid, structural=STRUCTURAL_REL_TYPES)
        for rel, src, dst in m["links"]:
            src_uid = _merge_stub(tx, tenant, src, m["site_id"])
            dst_uid = _merge_stub(tx, tenant, dst, m["site_id"])
            tx.run(f"MATCH (a:WorkItem {{uid: $a}}) MATCH (b:WorkItem {{uid: $b}}) "
                   f"MERGE (a)-[r:{rel}]->(b) "
                   "SET r.source_issue_uids = CASE WHEN $uid IN coalesce(r.source_issue_uids, []) "
                   "THEN coalesce(r.source_issue_uids, []) ELSE coalesce(r.source_issue_uids, []) + [$uid] END",
                   a=src_uid, b=dst_uid, uid=uid)


def write_comment(tx, c, issue_uid=None):
    old = tx.run("MATCH (c:Comment {uid: $uid}) RETURN c.updated AS updated", uid=c["uid"]).single()
    if old and is_stale(old.get("updated"), c["props"].get("updated")):
        return "skipped_stale"
    tx.run("MERGE (c:Comment {uid: $uid}) SET c += $props", uid=c["uid"], props=c["props"])
    if issue_uid:
        tx.run("MATCH (c:Comment {uid: $uid})<-[r:HAS_COMMENT]-() DELETE r", uid=c["uid"])
        _edge(tx, "WorkItem", issue_uid, "HAS_COMMENT", "Comment", c["uid"])
    _replace_out_edges(tx, c["uid"], "WRITTEN_BY", "Comment")
    _person_edge(tx, "Comment", c["uid"], "WRITTEN_BY", c["author"])


def write_worklog(tx, w, issue_uid=None):
    old = tx.run("MATCH (w:Worklog {uid: $uid}) RETURN w.updated AS updated", uid=w["uid"]).single()
    if old and is_stale(old.get("updated"), w["props"].get("updated")):
        return "skipped_stale"
    tx.run("MERGE (w:Worklog {uid: $uid}) SET w += $props", uid=w["uid"], props=w["props"])
    if issue_uid:
        tx.run("MATCH (w:Worklog {uid: $uid})<-[r:HAS_WORKLOG]-() DELETE r", uid=w["uid"])
        _edge(tx, "WorkItem", issue_uid, "HAS_WORKLOG", "Worklog", w["uid"])
    _replace_out_edges(tx, w["uid"], "LOGGED_BY", "Worklog")
    _person_edge(tx, "Worklog", w["uid"], "LOGGED_BY", w["author"])


def write_attachment(tx, a, issue_uid):
    tx.run("MERGE (a:Attachment {uid: $uid}) SET a += $props "
           "SET a.content_status = coalesce(a.content_status, 'not_processed')",
           uid=a["uid"], props=a["props"])
    tx.run("MATCH (a:Attachment {uid: $uid})<-[r:HAS_ATTACHMENT]-() DELETE r", uid=a["uid"])
    _edge(tx, "WorkItem", issue_uid, "HAS_ATTACHMENT", "Attachment", a["uid"])
    _replace_out_edges(tx, a["uid"], "UPLOADED_BY", "Attachment")
    _person_edge(tx, "Attachment", a["uid"], "UPLOADED_BY", a["author"])


def write_change(tx, ch, issue_uid):
    tx.run("MERGE (c:ChangeEvent {uid: $uid}) SET c += $props", uid=ch["uid"], props=ch["props"])
    tx.run("MATCH (c:ChangeEvent {uid: $uid})<-[r:HAD_CHANGE]-() DELETE r", uid=ch["uid"])
    _edge(tx, "WorkItem", issue_uid, "HAD_CHANGE", "ChangeEvent", ch["uid"])
    if ch["props"].get("field") == "assignee":
        tx.run("MATCH (c:ChangeEvent {uid: $uid}) SET c:AssignmentChange", uid=ch["uid"])
    _replace_out_edges(tx, ch["uid"], "CHANGED_BY", "ChangeEvent")
    _person_edge(tx, "ChangeEvent", ch["uid"], "CHANGED_BY", ch["author"])
    _replace_out_edges(tx, ch["uid"], "FROM_PERSON", "ChangeEvent")
    _replace_out_edges(tx, ch["uid"], "TO_PERSON", "ChangeEvent")
    _person_edge(tx, "ChangeEvent", ch["uid"], "FROM_PERSON", ch["from_person"], create_only=True)
    _person_edge(tx, "ChangeEvent", ch["uid"], "TO_PERSON", ch["to_person"], create_only=True)


def write_issue_events(tx, m, *, reconcile_state=False):
    """Claims/Events: بتتكتب دايمًا (idempotent) حتى لو الـ state قديم."""
    uid = m["uid"]
    if reconcile_state and m.get("payload_mode") == "full":
        attachment_uids = [a["uid"] for a in m.get("attachments", [])]
        tx.run("MATCH (w:WorkItem {uid: $uid})-[r:HAS_ATTACHMENT]->(a:Attachment) "
               "WHERE NOT a.uid IN $attachment_uids DELETE r",
               uid=uid, attachment_uids=attachment_uids)
        tx.run("MATCH (a:Attachment {tenant_id: $tenant, jira_site_id: $site}) "
               "WHERE NOT a.uid IN $attachment_uids "
               "AND NOT (:WorkItem)-[:HAS_ATTACHMENT]->(a) DETACH DELETE a",
               tenant=m["tenant_id"], site=m["site_id"], attachment_uids=attachment_uids)
    for c in m.get("comments", []):
        write_comment(tx, c, uid)
    for w in m.get("worklogs", []):
        write_worklog(tx, w, uid)
    if reconcile_state:
        for a in m.get("attachments", []):
            write_attachment(tx, a, uid)
    for ch in m.get("changes", []):
        write_change(tx, ch, uid)


def mark_reconcile_needed(tx, uid, reason):
    """Flag a WorkItem whose newest state could not be proven; a later snapshot clears it."""
    tx.run("MATCH (w:WorkItem {uid: $uid}) SET w.reconcile_needed = true, "
           "w.reconcile_reason = $reason, w.reconcile_flagged_at = $now",
           uid=uid, reason=reason, now=datetime.now(timezone.utc).isoformat())


def upsert_issue_detailed(tx, issue, tenant_id=DEFAULT_TENANT, *, changelog=None, actor=None,
                          event_time=None, force=False, field_meta=None,
                          payload_mode="partial", site_id=None, authoritative=False, browse_base=None):
    """
    Single entry point for any issue (bulk, webhook, reconciliation).
    Returns {"status", "uid", "ordering", "moved_from", "project_from"}.
    status: "upserted" | "state_skipped_stale" | "state_skipped_ambiguous".

    Ordering (see compare_versions): only a provably newer state overwrites. Events
    (changelog/comments/worklogs) are always written. `authoritative=True` marks the payload
    as a live Jira read made after the event: it applies unless provably older.
    """
    m = normalize_issue(issue, tenant_id, field_meta, changelog, actor, event_time,
                        payload_mode=payload_mode, site_id=site_id, browse_base=browse_base)
    info = {"status": None, "uid": m["uid"], "ordering": None,
            "moved_from": None, "project_from": None}
    adopt_workitem_identity(tx, m)
    row = tx.run("MATCH (w:WorkItem {uid: $uid}) RETURN w.updated AS updated, "
                 "w.summary AS summary, w.key AS key, w.project_key AS project_key, "
                 "w.last_changelog_id AS last_changelog_id, w.state_fp AS state_fp, "
                 "w.state_fp_mode AS state_fp_mode", uid=m["uid"]).single()
    if row and row.get("key") and row["key"] != m["key"]:
        info["moved_from"] = row["key"]
        if row.get("project_key") and row["project_key"] != m["props"].get("project_key"):
            info["project_from"] = row["project_key"]
    if not force and row and row["summary"] is not None:
        verdict = compare_versions(
            row["updated"], row.get("last_changelog_id"), m["props"].get("updated"),
            m.get("changelog_max_id"), event_time=event_time,
            existing_fp=row.get("state_fp"), incoming_fp=m.get("fingerprint"),
            existing_fp_mode=row.get("state_fp_mode"), incoming_fp_mode=m.get("payload_mode"))
        info["ordering"] = verdict
        if authoritative and verdict in ("ambiguous", "duplicate"):
            verdict = "newer"       # a live read is the best available truth at tie
        if verdict != "newer":
            write_issue_events(tx, m)
            if verdict == "ambiguous":
                mark_reconcile_needed(tx, m["uid"], "ambiguous_event_order")
                info["status"] = "state_skipped_ambiguous"
            else:
                info["status"] = "state_skipped_stale"
            return info
    write_issue_state(tx, m)
    write_issue_events(tx, m, reconcile_state=True)
    info["status"] = "upserted"
    return info


def upsert_issue(tx, issue, tenant_id=DEFAULT_TENANT, **kwargs):
    """Backward-compatible wrapper returning only the status string."""
    return upsert_issue_detailed(tx, issue, tenant_id, **kwargs)["status"]


# ---- entity-level upserts (للـ webhook) ----

def upsert_comment(tx, comment, tenant_id, issue_key=None, site_id=None):
    pk = project_key_of(issue_key) if issue_key else None
    site = site_id or jira_site_id()
    m = normalize_comment(comment, tenant_id, issue_key, pk, site)
    row = tx.run("MATCH (c:Comment {uid: $uid}) RETURN c.updated AS updated", uid=m["uid"]).single()
    if row and is_stale(row["updated"], m["props"].get("updated")):
        return "skipped_stale"
    issue_uid = _merge_stub(tx, tenant_id, issue_key, site) if issue_key else None
    write_comment(tx, m, issue_uid)
    return "upserted"


def upsert_sprint(tx, sprint, tenant_id, site_id=None):
    s = normalize_sprint(sprint, tenant_id, site_id)
    tx.run("MERGE (s:Sprint {uid: $uid}) SET s += $props", uid=s["uid"], props=s["props"])
    return "upserted"


def _find_workitem(tx, tenant_id, site, jira_id=None, key=None):
    return tx.run("MATCH (w:WorkItem {tenant_id: $t, jira_site_id: $s}) "
                  "WHERE w.jira_id = $id OR w.key = $key "
                  "RETURN w.uid AS uid, w.key AS key, w.project_key AS project_key LIMIT 1",
                  t=tenant_id, s=site, id=str(jira_id) if jira_id is not None else None,
                  key=key).single()


def upsert_attachment(tx, attachment, tenant_id, site_id, issue_id=None, issue_key=None):
    """-> False when the owning issue is unknown: its next snapshot carries the attachment."""
    row = _find_workitem(tx, tenant_id, site_id, issue_id, issue_key)
    if not row:
        return False
    write_attachment(tx, normalize_attachment(attachment, tenant_id, row["key"], row["project_key"], site_id),
                     row["uid"])
    return True


def apply_issue_link(tx, link, tenant_id, site_id, remove=False):
    """Native issuelink_created/deleted event: source -outward-> destination. -> False when
    either issue is not in the graph: its next snapshot carries the link."""
    a = _find_workitem(tx, tenant_id, site_id, link.get("sourceIssueId"))
    b = _find_workitem(tx, tenant_id, site_id, link.get("destinationIssueId"))
    if not a or not b:
        return False
    rel = rel_type_of((link.get("issueLinkType") or {}).get("outwardName"))
    if remove:
        tx.run(f"MATCH (a:WorkItem {{uid: $a}})-[r:{rel}]->(b:WorkItem {{uid: $b}}) DELETE r",
               a=a["uid"], b=b["uid"])
    else:
        tx.run(f"MATCH (a:WorkItem {{uid: $a}}) MATCH (b:WorkItem {{uid: $b}}) MERGE (a)-[r:{rel}]->(b) "
               "SET r.source_issue_uids = CASE WHEN $a IN coalesce(r.source_issue_uids, []) "
               "THEN r.source_issue_uids ELSE coalesce(r.source_issue_uids, []) + [$a] END",
               a=a["uid"], b=b["uid"])
    return True


def delete_tenant(tx, tenant_id, limit=1000):
    """One batch of a company's whole graph (integration disconnected). -> nodes removed."""
    require_tenant(tenant_id)
    return tx.run("MATCH (n) WHERE n.tenant_id = $t WITH n LIMIT $limit "
                  "DETACH DELETE n RETURN count(*) AS n", t=tenant_id, limit=limit).single()["n"]


def upsert_project(tx, project, tenant_id, site_id=None):
    p = normalize_project(project, tenant_id, site_id)
    site = p["props"]["jira_site_id"]
    adopt_project_identity(tx, p)
    tx.run("MERGE (p:Project {uid: $uid}) SET p += $props", uid=p["uid"], props=p["props"])
    return "upserted"


def upsert_person(tx, user, tenant_id):
    p = normalize_person(user, tenant_id)
    if not p:
        return "no_account_id"
    _merge_person(tx, p)
    return "upserted"


def upsert_worklog(tx, worklog, tenant_id, site_id=None):
    site = site_id or jira_site_id()
    w = normalize_worklog(worklog, tenant_id, site_id=site)
    old = tx.run("MATCH (w:Worklog {uid: $uid}) RETURN w.updated AS updated", uid=w["uid"]).single()
    if old and is_stale(old.get("updated"), w["props"].get("updated")):
        return "skipped_stale"
    tx.run("MERGE (w:Worklog {uid: $uid}) SET w += $props", uid=w["uid"], props=w["props"])
    # الـ webhook بيبعت issueId (مش key): بنربطه بالـ jira_id المخزّن على الـ WorkItem
    tx.run("MATCH (wl:Worklog {uid: $uid})<-[r:HAS_WORKLOG]-() DELETE r", uid=w["uid"])
    tx.run("""
        MATCH (wl:Worklog {uid: $uid})
        OPTIONAL MATCH (i:WorkItem {jira_id: $issue_id, tenant_id: $t, jira_site_id: $site})
        FOREACH (_ IN CASE WHEN i IS NULL THEN [] ELSE [1] END |
            MERGE (i)-[:HAS_WORKLOG]->(wl)
            SET wl.issue_key = i.key, wl.project_key = i.project_key)
    """, uid=w["uid"], issue_id=w["props"].get("issue_id"), t=tenant_id, site=site)
    _replace_out_edges(tx, w["uid"], "LOGGED_BY", "Worklog")
    _person_edge(tx, "Worklog", w["uid"], "LOGGED_BY", w["author"])
    return "upserted"


# ---- logical deletion guard plus graph cleanup ----

def _remove_evidence_for_source(tx, source_uid, source_key):
    """Remove only this source's evidence/ownership; preserve edges with other sources."""
    tx.run(
        "MATCH ()-[r]->() WHERE "
        "(r.evidence IS NOT NULL AND any(e IN r.evidence WHERE e = $uid OR e = $key)) "
        "OR $uid IN coalesce(r.source_issue_uids, []) "
        "SET r.evidence = [e IN coalesce(r.evidence, []) WHERE e <> $uid AND e <> $key], "
        "r.source_issue_uids = [x IN coalesce(r.source_issue_uids, []) WHERE x <> $uid] "
        "WITH r WHERE size(r.evidence) = 0 AND size(r.source_issue_uids) = 0 DELETE r",
        uid=source_uid, key=source_key)


def delete_issue(tx, key, tenant_id, _seen=None, *, jira_id=None, site_id=None,
                 deletion_time=None, issue_type=None):
    """Hard delete: remove the issue, its own records and its hierarchical descendants.

    Deleting an Epic preserves its Stories; deleting any other issue recursively deletes
    all descendants reachable through actual CHILD_OF edges. No trace is kept, so if the
    issue is sent again it is stored again (this includes a webhook that arrives late).
    """
    _seen = set() if _seen is None else _seen
    if key in _seen:
        return "already_deleted"
    _seen.add(key)
    # Scope is mandatory: never guess a site (a fallback such as "unknown" could delete
    # another instance's issue that happens to share a key).
    site_hint = jira_site_id(None, site_id)
    rows = list(tx.run(
        "MATCH (w:WorkItem {tenant_id: $t}) "
        "WHERE (w.jira_site_id = $site OR w.jira_site_id IS NULL) "
        "AND (w.key = $key OR $key IN coalesce(w.key_aliases, [])) "
        "RETURN w.uid AS uid, w.key AS key, w.jira_id AS jira_id, "
        "w.jira_site_id AS site_id, w.issuetype AS issuetype, "
        "w.key_aliases AS key_aliases",
        t=tenant_id, key=key, site=site_hint))
    if len(rows) > 1:
        raise IdentityConflictError(f"Deletion key {key} resolves to multiple WorkItems")
    row = rows[0] if rows else None
    current_key = row["key"] if row else key
    issue_id = str(jira_id or (row["jira_id"] if row else "") or "").strip()
    site = (row["site_id"] if row else None) or site_hint
    site = re.sub(r"[^A-Za-z0-9_.-]", "_", str(site).strip().lower())
    source_uid = row["uid"] if row else (workitem_uid(tenant_id, site, issue_id) if issue_id else f"{tenant_id}:{current_key}")
    _remove_evidence_for_source(tx, source_uid, current_key)
    for alias in (row["key_aliases"] or [] if row else []):
        _remove_evidence_for_source(tx, source_uid, alias)

    # Epic deletion is explicitly non-cascading: Stories remain and lose this parent edge.
    actual_type = (row["issuetype"] if row else issue_type) or ""
    if actual_type.lower() != "epic":
        children = [r["k"] for r in tx.run(
            "MATCH (s:WorkItem {tenant_id: $t})-[:CHILD_OF]->"
            "(p:WorkItem {tenant_id: $t}) WHERE p.key = $key "
            "RETURN s.key AS k", t=tenant_id, key=current_key)]
        for child_key in children:
            delete_issue(tx, child_key, tenant_id, _seen, site_id=site,
                         deletion_time=deletion_time)

    tx.run("MATCH (w:WorkItem {uid: $uid})-[:HAS_COMMENT|HAS_ATTACHMENT|HAS_WORKLOG|HAD_CHANGE]->(o) "
           "DETACH DELETE o", uid=source_uid)
    issue_keys = list(dict.fromkeys([current_key, key] + (row["key_aliases"] or [] if row else [])))
    tx.run("MATCH (o) WHERE o.tenant_id = $tenant AND o.jira_site_id = $site "
           "AND (o.issue_key IN $keys OR o.issue_id = $jira_id) "
           "AND (o:Comment OR o:Attachment OR o:Worklog OR o:ChangeEvent) "
           "DETACH DELETE o", tenant=tenant_id, site=site, keys=issue_keys,
           jira_id=issue_id or None)
    if row:
        tx.run("MATCH (w:WorkItem {uid: $uid}) DETACH DELETE w", uid=source_uid)
    else:
        # Deletion arrived before any full snapshot: remove a key-only stub if there is one.
        tx.run("MATCH (w:WorkItem {tenant_id: $t}) WHERE w.key = $key "
               "OR $key IN coalesce(w.key_aliases, []) DETACH DELETE w",
               t=tenant_id, key=current_key)
    return "deleted"


def delete_issue_by_id(tx, jira_id, tenant_id, site_id=None, deletion_time=None):
    """Deletion addressed by Jira issue id only (the backend's internal {type,id} notice).
    Resolves the current key through the stored id; if the issue was never ingested, only
    orphan records carrying that id are removed."""
    site = jira_site_id(None, site_id)
    jid = str(jira_id).strip()
    row = tx.run("MATCH (w:WorkItem {tenant_id: $t, jira_id: $id}) "
                 "WHERE w.jira_site_id = $site OR w.jira_site_id IS NULL "
                 "RETURN w.key AS key, w.uid AS uid", t=tenant_id, id=jid, site=site).single()
    if row and row.get("key"):
        return delete_issue(tx, row["key"], tenant_id, site_id=site, jira_id=jid,
                            deletion_time=deletion_time)
    tx.run("MATCH (o) WHERE o.tenant_id = $tenant AND o.jira_site_id = $site "
           "AND o.issue_id = $jira_id "
           "AND (o:Comment OR o:Attachment OR o:Worklog OR o:ChangeEvent) DETACH DELETE o",
           tenant=tenant_id, site=site, jira_id=jid)
    return "deleted"


def delete_entity(tx, label, uid, tenant_id=None, site_id=None, deletion_time=None):
    """Hard-delete a Comment/Worklog. No trace is kept."""
    return delete_by_uid(tx, label, uid)


def delete_by_uid(tx, label, uid):
    if label not in ("Comment", "Sprint", "Person", "Worklog", "IssueType", "Board", "Project",
                     "Attachment"):
        raise ValueError(f"label not allowed: {label}")
    tx.run(f"MATCH (n:{label} {{uid: $uid}}) DETACH DELETE n", uid=uid)
    return "deleted"