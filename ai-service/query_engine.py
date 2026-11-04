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
MAX_CHILD_ITEMS = 10
MAX_HISTORY = 5
MAX_COMMENTS = 3
MAX_DESCRIPTION_CHARS = 1500

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

def get_workitem_card(key, ctx):
    records = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, []))
          AND w.project_key IN $allowed
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        OPTIONAL MATCH (w)-[:IN_SPRINT]->(s:Sprint)
        OPTIONAL MATCH (w)-[:CHILD_OF]->(par:WorkItem)
        RETURN w.key AS key, w.summary AS summary, w.status AS status,
               w.statusCategory AS category, w.priority AS priority,
               w.issuetype AS issuetype, w.project_key AS project, w.url AS url,
               w.duedate AS duedate, a.displayName AS assignee,
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
        "duedate": r.get("duedate"),
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
            RETURN c.key AS rkey, c.summary AS summary, c.status AS status,
                   c.url AS url, c.project_key AS project, p.displayName AS assignee
            ORDER BY CASE c.statusCategory WHEN 'done' THEN 1 ELSE 0 END, c.key
            LIMIT $limit
            """,
            key=key, limit=limit, **_scope(ctx),
        )
        items = _items_from(rows, ctx)
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