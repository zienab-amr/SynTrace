"""
query_engine.py
GraphRAG retrieval layer (no LLM): Cypher templates ثابتة.

الأمان: كل دالة بتاخد ctx (AccessContext) إجباري: tenant_id + allowed_projects.
الفلترة بتحصل جوه الـ Cypher، يعني قبل ما أي حاجة توصل للـ LLM.
دلوقتي ctx جاي من default_context() (قيمة ثابتة من الـ env/graph)، ولما يبقى فيه login
حقيقي بيتبدّل من غير ما أي دالة هنا تتغيّر.
"""
import logging
import os
import json
import re
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()

# Neo4j بتحذّر لما query بتسأل عن property/relationship لسه ما اتعملتش (مثلًا قبل أول changelog).
# طبيعي ومش خطأ، فبنسكّتها. NEO4J_NOTIFICATIONS=1 لو عايزة تشوفيها وإنتِ بتطوّري.
if os.getenv("NEO4J_NOTIFICATIONS") != "1":
    logging.getLogger("neo4j.notifications").setLevel(logging.ERROR)

MAX_KEYS = 5
MAX_RESULTS = 20
MAX_CHILD_ITEMS = 25
MAX_HISTORY = 5
MAX_CHANGES = 20
MAX_COMMENTS = 10
MAX_DESCRIPTION_CHARS = 1500
MAX_CUSTOM_FIELDS = 15
MAX_CUSTOM_FIELD_CHARS = 200
HIDDEN_FIELD_KINDS = {"sprint", "rank", "json_string", "object", "unknown"}

_driver = None


def get_driver():
    global _driver
    if _driver is None:
        from neo4j import GraphDatabase
        _driver = GraphDatabase.driver(
            os.getenv("NEO4J_URI"), auth=(os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASSWORD")))
    return _driver


def run_query(query, **params):
    """المكان الوحيد اللي بيكلّم Neo4j."""
    with get_driver().session() as session:
        return list(session.run(query, **params))


# ---------- Access context ----------

@dataclass(frozen=True)
class AccessContext:
    tenant_id: str
    allowed_projects: tuple  # فاضية = مفيش حاجة تتشاف (deny by default)
    jira_account_id: str = None  # who is asking, for questions such as "my tickets"


def default_context():
    """CLI / dev convenience ONLY. A service must build AccessContext from the authenticated
    request (tenant + allowed projects decided by the backend), never from the environment.
    Fails closed: no TENANT_ID -> error; no ALLOWED_PROJECTS -> empty scope (sees nothing)."""
    tenant = os.getenv("TENANT_ID")
    if not tenant:
        raise ValueError("TENANT_ID is required")
    env = os.getenv("ALLOWED_PROJECTS")
    allowed = tuple(p.strip().upper() for p in env.split(",") if p.strip()) if env else ()
    return AccessContext(tenant, allowed)


def _scope(ctx):
    return {"tenant": ctx.tenant_id, "allowed": list(ctx.allowed_projects)}


# ---------- Helpers ----------

_GENERIC_KEY = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*-\d+)\b")


def extract_keys(question, ctx=None):
    """
    Restrict ordinary key extraction to allowed projects. Historical aliases from a
    moved project are resolved separately against WorkItems in the allowed scope.
    """
    pattern = _GENERIC_KEY
    if ctx is not None and ctx.allowed_projects:
        alt = "|".join(re.escape(p) for p in sorted(ctx.allowed_projects, key=len, reverse=True))
        pattern = re.compile(rf"\b((?:{alt})-\d+)\b", re.IGNORECASE)
    found = [m.upper() for m in pattern.findall(question)]
    return list(dict.fromkeys(found))[:MAX_KEYS]


def normalize_status(status):
    if not status:
        return "Unknown"
    return status.strip()


def build_item(rkey, summary, status, url, assignee, project=None, allowed=None):
    """
    عنصر مرتبط. incomplete لو الـ node فاضي (مايخترعش بيانات).
    restricted لو من مشروع مش مسموح: بنعرض key + summary بس (reference)، من غير status/assignee/url.
    """
    if summary is None:
        return {"key": rkey, "summary": None, "status": "Unknown",
                "assignee": "Unknown", "url": url, "incomplete": True}
    if allowed is not None and project is not None and project not in allowed:
        return {"key": rkey, "summary": summary, "status": "Restricted",
                "assignee": "Restricted", "url": None,
                "incomplete": False, "restricted": True}
    return {"key": rkey, "summary": summary, "status": normalize_status(status),
            "assignee": assignee or "Unassigned", "url": url, "incomplete": False}


def _items_from(records, ctx):
    allowed = set(ctx.allowed_projects)
    return [
        build_item(r["rkey"], r["summary"], r["status"], r["url"], r["assignee"],
                   r["project"], allowed)
        for r in records if r["rkey"] is not None
    ]


# ---------- Retrieval functions ----------

def readable_custom_fields(fields_json, defs_json):
    """Custom fields worth showing, by display name. Internal fields such as Rank, Sprint and
    Development and long or structured values are left out to keep the LLM context small."""
    try:
        fields = json.loads(fields_json) if fields_json else {}
        defs = json.loads(defs_json) if defs_json else {}
    except ValueError:
        return {}
    if not isinstance(fields, dict) or not isinstance(defs, dict):
        return {}
    hidden = {d.get("name") for d in defs.values() if isinstance(d, dict)
              and d.get("kind") in HIDDEN_FIELD_KINDS}
    shown = {}
    for name, value in fields.items():
        if name in hidden or value in (None, "", [], {}):
            continue
        if isinstance(value, list) and all(isinstance(item, (str, int, float)) for item in value):
            value = ", ".join(str(item) for item in value)
        if isinstance(value, (str, int, float, bool)) and len(str(value)) <= MAX_CUSTOM_FIELD_CHARS:
            shown[name] = value
        if len(shown) == MAX_CUSTOM_FIELDS:
            break
    return shown


def get_workitem_card(key, ctx):
    records = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        OPTIONAL MATCH (w)-[:IN_SPRINT]->(s:Sprint)
        OPTIONAL MATCH (w)-[:CHILD_OF]->(par:WorkItem)
        OPTIONAL MATCH (w)-[:REPORTED_BY]->(rp:Person)
        RETURN w.key AS key, w.summary AS summary, w.status AS status,
               w.statusCategory AS category, w.priority AS priority,
               w.issuetype AS issuetype, w.project_key AS project, w.url AS url,
               w.duedate AS duedate, w.created AS created, w.updated AS updated,
               w.resolutiondate AS resolved, w.labels AS labels, w.components AS components,
               rp.displayName AS reporter, w.custom_fields AS custom_fields,
               w.custom_field_defs AS custom_field_defs, a.displayName AS assignee,
               CASE WHEN par.project_key IN $allowed THEN par.key END AS parent,
               collect(DISTINCT s.name) AS sprints
        """,
        key=key, **_scope(ctx),
    )
    if not records or records[0]["key"] is None:
        return None
    r = records[0]
    if r["summary"] is None:
        return {"key": key, "incomplete": True}
    return {
        "key": r["key"], "summary": r["summary"],
        "status": normalize_status(r["status"]), "status_category": r["category"],
        "priority": r["priority"] or "None", "issuetype": r["issuetype"],
        "project": r["project"], "assignee": r["assignee"] or "Unassigned",
        "parent": r["parent"], "sprints": r["sprints"] or [], "url": r["url"],
        "duedate": r.get("duedate"), "created": r.get("created"), "updated": r.get("updated"),
        "resolved": r.get("resolved"), "labels": r.get("labels") or [],
        "components": r.get("components") or [], "reporter": r.get("reporter"),
        "custom_fields": readable_custom_fields(r.get("custom_fields"), r.get("custom_field_defs")),
    }


def get_children(key, ctx, limit=MAX_CHILD_ITEMS):
    """
    Subtasks / أي تذكرة CHILD_OF لها (test cases، stories تحت epic...).
    بترجّع تجميع (total + by status category + by type) + أول `limit` عنصر (اللي لسه مخلصش الأول).
    مش بنحط مئات العناصر في الـ prompt.
    """
    counts = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        OPTIONAL MATCH (c:WorkItem)-[:CHILD_OF]->(w)
        WHERE c.tenant_id = $tenant AND c.project_key IN $allowed
        RETURN c.issuetype AS issuetype, c.statusCategory AS category, count(c) AS n
        """,
        key=key, **_scope(ctx),
    )
    if not counts:
        return None
    by_cat, by_type, total = {}, {}, 0
    for r in counts:
        if not r["n"]:
            continue
        total += r["n"]
        cat = r["category"] or "unknown"
        by_cat[cat] = by_cat.get(cat, 0) + r["n"]
        typ = r["issuetype"] or "unknown"
        by_type[typ] = by_type.get(typ, 0) + r["n"]
    items = []
    if total and limit > 0:
        rows = run_query(
            """
            MATCH (w:WorkItem {tenant_id: $tenant})
            WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
              AND w.project_key IN $allowed
            MATCH (c:WorkItem)-[:CHILD_OF]->(w)
            WHERE c.tenant_id = $tenant AND c.project_key IN $allowed
            OPTIONAL MATCH (c)-[:ASSIGNED_TO]->(p:Person)
            OPTIONAL MATCH (b:WorkItem {tenant_id: $tenant})-[:BLOCKS]->(c)
            WHERE b.project_key IN $allowed
            WITH c, p, collect(DISTINCT b.key) AS blockers
            RETURN c.key AS rkey, c.summary AS summary, c.status AS status,
                   c.url AS url, c.project_key AS project, p.displayName AS assignee, blockers
            ORDER BY CASE c.statusCategory WHEN 'done' THEN 1 ELSE 0 END, c.key
            LIMIT $limit
            """,
            key=key, limit=limit, **_scope(ctx),
        )
        items = _items_from(rows, ctx)
        blocked = {r["rkey"]: r.get("blockers") or [] for r in rows}
        for item in items:
            item["blockers"] = blocked.get(item["key"], [])
    return {"key": key, "total": total, "by_status_category": by_cat,
            "by_type": by_type, "items": items, "more": max(0, total - len(items))}


def get_assignment_history(key, ctx, limit=MAX_HISTORY):
    """تاريخ تغيير الـ assignee (من الـ changelog)، الأحدث الأول."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        MATCH (w)-[:HAD_CHANGE]->(c:ChangeEvent {field: 'assignee'})
        RETURN c.changed_at AS at, c.from_name AS from_name,
               c.to_name AS to_name, c.author AS by
        ORDER BY c.changed_at DESC
        LIMIT $limit
        """,
        key=key, limit=limit, **_scope(ctx),
    )
    return [{"at": r["at"], "from": r["from_name"] or "Unassigned",
             "to": r["to_name"] or "Unassigned", "by": r["by"]} for r in rows]


def get_change_history(key, ctx, limit=MAX_CHANGES, oldest_first=False):
    """Every field change on one ticket, latest first unless asked for the oldest first."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        MATCH (w)-[:HAD_CHANGE]->(c:ChangeEvent)
        RETURN c.changed_at AS at, c.field AS field, c.from_name AS from_name,
               c.to_name AS to_name, c.author AS by
        ORDER BY c.changed_at """ + ("ASC" if oldest_first else "DESC") + """
        LIMIT $limit
        """,
        key=key, limit=limit, **_scope(ctx),
    )
    return [{"at": r["at"], "field": r["field"], "from": r["from_name"], "to": r["to_name"],
             "by": r["by"]} for r in rows]


def get_recent_comments(key, ctx, limit=MAX_COMMENTS):
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        OPTIONAL MATCH (w)-[:HAS_COMMENT]->(c:Comment)
        OPTIONAL MATCH (c)-[:WRITTEN_BY]->(p:Person)
        WITH c, p ORDER BY c.created DESC
        RETURN count(c) AS total,
               collect(CASE WHEN c IS NULL THEN NULL
                            ELSE {text: c.text, created: c.created, author: p.displayName} END)[0..$limit] AS latest
        """,
        key=key, limit=limit, **_scope(ctx),
    )
    if not rows:
        return {"total": 0, "latest": []}
    return {"total": rows[0]["total"], "latest": rows[0]["latest"] or []}


def get_description(key, ctx, max_chars=MAX_DESCRIPTION_CHARS):
    """وصف التذكرة كنص (بحد أقصى، عشان الـ prompt ما يتضخمش)."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        RETURN w.description_text AS text
        """,
        key=key, **_scope(ctx),
    )
    if not rows or not rows[0]["text"]:
        return ""
    text = rows[0]["text"].strip()
    return text if len(text) <= max_chars else text[:max_chars].rstrip() + " ..."


def get_attachments(key, ctx, limit=MAX_HISTORY):
    """Attachment metadata only: the file contents are not read yet."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        MATCH (w)-[:HAS_ATTACHMENT]->(a:Attachment)
        OPTIONAL MATCH (a)-[:UPLOADED_BY]->(p:Person)
        RETURN a.filename AS filename, a.mimeType AS mime, a.kind AS kind, a.size AS size,
               a.created AS created, p.displayName AS author
        ORDER BY a.created DESC
        LIMIT $limit
        """,
        key=key, limit=limit, **_scope(ctx),
    )
    return [dict(r) for r in rows]


def get_worklogs(key, ctx, limit=MAX_RESULTS):
    """Time logged on one ticket, per person."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        MATCH (w)-[:HAS_WORKLOG]->(l:Worklog)
        OPTIONAL MATCH (l)-[:LOGGED_BY]->(p:Person)
        WITH coalesce(p.displayName, 'Unknown') AS author,
             sum(coalesce(l.timeSpentSeconds, 0)) AS seconds, count(l) AS entries
        RETURN author, seconds, entries
        ORDER BY seconds DESC
        LIMIT $limit
        """,
        key=key, limit=limit, **_scope(ctx),
    )
    return [{"author": r["author"], "seconds": r["seconds"], "entries": r["entries"]} for r in rows]


def get_ticket_details(key, ctx):
    """الكارت + subtasks + assignment history + آخر كومنتات (كلهم بحدود، للـ LLM context)."""
    card = get_workitem_card(key, ctx)
    if card is None or card.get("incomplete"):
        return card
    card["description"] = get_description(key, ctx)
    card["children"] = get_children(key, ctx) or {"total": 0, "items": [], "more": 0,
                                                  "by_status_category": {}, "by_type": {}}
    card["assignment_history"] = get_assignment_history(key, ctx)
    card["changes"] = get_change_history(key, ctx)
    card["comments"] = get_recent_comments(key, ctx)
    card["attachments"] = get_attachments(key, ctx)
    card["worklogs"] = get_worklogs(key, ctx)
    return card


def _get_relation(key, ctx, match_clause):
    records = run_query(
        f"""
        MATCH (w:WorkItem {{tenant_id: $tenant}})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        {match_clause}
        OPTIONAL MATCH (r)-[:ASSIGNED_TO]->(p:Person)
        RETURN r.key AS rkey, r.summary AS summary, r.status AS status,
               r.url AS url, r.project_key AS project, p.displayName AS assignee
        ORDER BY r.key
        LIMIT $limit
        """,
        key=key, limit=MAX_RESULTS, **_scope(ctx),
    )
    if not records:
        return None
    return {"key": key, "items": _items_from(records, ctx)}


def get_blockers(key, ctx):
    """Tickets that block this ticket: (r)-[:BLOCKS]->(w)."""
    return _get_relation(key, ctx,
                         "OPTIONAL MATCH (r:WorkItem {tenant_id: $tenant})-[:BLOCKS]->(w)")


def get_blocked_by_me(key, ctx):
    """Tickets blocked by this ticket: (w)-[:BLOCKS]->(r)."""
    return _get_relation(key, ctx,
                         "OPTIONAL MATCH (w)-[:BLOCKS]->(r:WorkItem {tenant_id: $tenant})")


def get_related(key, ctx):
    """RELATES_TO في الاتجاهين."""
    return _get_relation(key, ctx,
                         "OPTIONAL MATCH (w)-[:RELATES_TO]-(r:WorkItem {tenant_id: $tenant})")


def get_all_relations(key, ctx):
    """Every link of this ticket, of any type and in both directions. Link types come from each
    Jira site, so none is named here. CHILD_OF is hierarchy and comes with the ticket details."""
    records = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, [])) AND w.project_key IN $allowed
        MATCH (w)-[link]-(r:WorkItem {tenant_id: $tenant})
        WHERE type(link) <> 'CHILD_OF'
        OPTIONAL MATCH (r)-[:ASSIGNED_TO]->(p:Person)
        RETURN type(link) AS relation, startNode(link) = w AS outgoing, r.key AS rkey,
               r.summary AS summary, r.status AS status, r.url AS url,
               r.project_key AS project, p.displayName AS assignee
        ORDER BY relation, r.key
        LIMIT $limit
        """,
        key=key, limit=MAX_RESULTS, **_scope(ctx))
    allowed = set(ctx.allowed_projects)
    return [{**build_item(r["rkey"], r["summary"], r["status"], r["url"], r["assignee"], r["project"], allowed),
             "relation": r["relation"], "outgoing": r["outgoing"]} for r in records if r["rkey"]]


INTERNAL_PROPERTIES = {"uid", "tenant_id", "jira_site_id", "jira_id", "key_aliases", "last_changelog_id",
                       "reconcile_needed", "custom_fields", "custom_field_defs", "embedding", "url"}


def _shown(name):
    return (name not in INTERNAL_PROPERTIES and not name.startswith("embedding")
            and not name.endswith(("_hash", "_raw", "_account_id")))


def get_everything(key, ctx):
    """Every stored field of one ticket, whatever fields its Jira site has, plus its people, parent,
    sprints and how many comments, worklogs, attachments, changes and child tickets it has."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, [])) AND w.project_key IN $allowed
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        OPTIONAL MATCH (w)-[:REPORTED_BY]->(r:Person)
        OPTIONAL MATCH (w)-[:CHILD_OF]->(par:WorkItem)
        WITH w, a, r, CASE WHEN par.project_key IN $allowed THEN par END AS par
        OPTIONAL MATCH (w)-[:IN_SPRINT]->(s:Sprint)
        WITH w, a, r, par, collect(DISTINCT {name: s.name, state: s.state, start: s.startDate, end: s.endDate}) AS sprints
        RETURN properties(w) AS props, a.displayName AS assignee, r.displayName AS reporter,
               par.key AS parent, par.summary AS parent_summary, par.issuetype AS parent_type, sprints,
               COUNT { (w)-[:HAS_COMMENT]->() } AS comments, COUNT { (w)-[:HAS_WORKLOG]->() } AS worklogs,
               COUNT { (w)-[:HAS_ATTACHMENT]->() } AS attachments, COUNT { (w)-[:HAD_CHANGE]->() } AS changes,
               COUNT { (w)<-[:CHILD_OF]-() } AS children
        """,
        key=key, **_scope(ctx))
    if not rows or not rows[0]["props"].get("summary"):
        return None
    r = rows[0]
    props = r["props"]
    fields = {k: v for k, v in sorted(props.items()) if _shown(k) and v not in (None, "", [])}
    fields.update(readable_custom_fields(props.get("custom_fields"), props.get("custom_field_defs")) or {})
    fields["assignee"] = r["assignee"] or "Unassigned"
    if r["reporter"]:
        fields["reporter"] = r["reporter"]
    if r["parent"]:
        fields["parent"] = f"{r['parent']} ({r['parent_type']}): {r['parent_summary']}"
    sprints = [s for s in r["sprints"] if s.get("name")]
    if sprints:
        fields["sprints"] = "; ".join(f"{s['name']} ({s.get('state')}, {s.get('start')} to {s.get('end')})" for s in sprints)
    for name in ("comments", "worklogs", "attachments", "changes", "children"):
        fields[f"number of {name}"] = r[name]
    return {"key": props.get("key"), "url": props.get("url"), "fields": fields}


def find_comments(key, ctx, author=None, contains=None, oldest_first=False, limit=MAX_COMMENTS):
    """One ticket's comments with their full text, filtered in the graph by author or words."""
    order = "ASC" if oldest_first else "DESC"
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, [])) AND w.project_key IN $allowed
        MATCH (w)-[:HAS_COMMENT]->(c:Comment)
        OPTIONAL MATCH (c)-[:WRITTEN_BY]->(p:Person)
        WITH c, p WHERE ($author IS NULL OR toLower(p.displayName) CONTAINS $author)
                    AND ($contains IS NULL OR toLower(c.text) CONTAINS $contains)
        RETURN c.text AS text, c.created AS created, p.displayName AS author
        ORDER BY c.created """ + order + """
        LIMIT $limit
        """,
        key=key, author=(author or "").lower() or None, contains=(contains or "").lower() or None,
        limit=limit, **_scope(ctx))
    return [dict(r) for r in rows]


def find_tickets(ctx, project=None, issuetype=None, status=None, assignee=None, parent=None,
                 sprint=None, text=None, limit=MAX_RESULTS):
    """Tickets that match every filter given, with the total. The graph does the filtering."""
    low = {k: (v or "").strip().lower() or None for k, v in
           {"project": project, "issuetype": issuetype, "status": status, "assignee": assignee,
            "sprint": sprint, "text": text}.items()}
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE w.project_key IN $allowed AND w.summary IS NOT NULL
          AND ($project IS NULL OR toLower(w.project_key) = $project)
          AND ($issuetype IS NULL OR toLower(w.issuetype) CONTAINS $issuetype)
          AND ($status IS NULL OR toLower(w.status) CONTAINS $status OR toLower(w.statusCategory) = $status)
          AND ($text IS NULL OR toLower(w.summary) CONTAINS $text)
          AND ($parent IS NULL OR EXISTS { MATCH (w)-[:CHILD_OF]->(p:WorkItem) WHERE p.key = $parent })
          AND ($sprint IS NULL OR EXISTS { MATCH (w)-[:IN_SPRINT]->(s:Sprint)
                                           WHERE toLower(s.name) CONTAINS $sprint OR toLower(s.state) = $sprint })
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        WITH w, a WHERE $assignee IS NULL OR toLower(a.displayName) CONTAINS $assignee
        WITH w, a ORDER BY w.key
        WITH collect({key: w.key, summary: w.summary, type: w.issuetype, status: w.status,
                      assignee: coalesce(a.displayName, 'Unassigned'), url: w.url}) AS items
        RETURN size(items) AS total, items[0..$limit] AS items
        """,
        parent=(parent or "").strip().upper() or None, limit=limit, **low, **_scope(ctx))
    return rows[0] if rows else {"total": 0, "items": []}


# ---------- Entry point ----------

def answer_key_question(question, ctx):
    """list من النتايج، واحدة لكل key. types: found | incomplete | not_found | no_key_found"""
    keys = extract_keys(question, ctx)
    if ctx.allowed_projects:
        candidates = [k.upper() for k in _GENERIC_KEY.findall(question)]
        other_candidates = [k for k in dict.fromkeys(candidates) if k not in keys]
        if other_candidates:
            rows = run_query(
                "UNWIND $keys AS requested "
                "MATCH (w:WorkItem {tenant_id: $tenant}) "
                "WHERE w.project_key IN $allowed AND requested IN coalesce(w.key_aliases, []) "
                "RETURN DISTINCT requested AS key LIMIT $limit",
                keys=other_candidates, limit=MAX_KEYS, **_scope(ctx))
            keys.extend(r["key"] for r in rows if r["key"] not in keys)
            keys = keys[:MAX_KEYS]
    if not keys:
        return [{"type": "no_key_found", "message": "No ticket key found in the question."}]
    results = []
    for key in keys:
        card = get_workitem_card(key, ctx)
        if card is None:
            results.append({"type": "not_found", "key": key,
                            "message": f"No ticket found with key {key}."})
        elif card.get("incomplete"):
            results.append({"type": "incomplete", "key": key,
                            "message": f"Ticket {key} is referenced but its data is incomplete."})
        else:
            results.append({"type": "found", "card": card})
    return results


if __name__ == "__main__":
    ctx = default_context()
    print("context:", ctx)
    for q in ["What is the status of SYNTECH-5?", "Compare SYNTECH-5 and SYNDATA-12",
              "What about SYNTECH-9999?", "How is the weather today?"]:
        print(f"\nQ: {q}")
        for res in answer_key_question(q, ctx):
            print("  ->", res)
    print("\nchildren SYNTECH-3:", get_children("SYNTECH-3", ctx))
    print("blockers SYNDATA-3:", get_blockers("SYNDATA-3", ctx))