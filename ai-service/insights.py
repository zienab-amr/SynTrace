"""
insights.py
Read-only views over the graph that a team lead asks for, beyond single tickets:

- readiness: open tickets that are not ready to work on (no description, no assignee,
  no story points, no acceptance criteria).
- stuck: open tickets whose status has not changed for a long time.
- sprint_summary: one sprint's done, open and blocked work, with who finished each ticket.
- uncovered_requirements: approved client requirements and action items from meetings that are
  linked to no Jira ticket.

Every query is scoped to the company and its allowed projects. Nothing here writes.
"""
import re
from datetime import datetime, timezone

from query_engine import _scope, run_query

LIMIT = 25
DONE = "done"

_FILTERS = """
  AND ($project IS NULL OR toLower(w.project_key) = $project)
  AND ($issuetype IS NULL OR toLower(w.issuetype) CONTAINS $issuetype)
  AND ($sprint IS NULL OR EXISTS { MATCH (w)-[:IN_SPRINT]->(s:Sprint)
                                   WHERE toLower(s.name) CONTAINS $sprint OR toLower(s.state) = $sprint })
"""


def _low(**values):
    return {k: (str(v).strip().lower() or None) if v else None for k, v in values.items()}


def readiness(ctx, project=None, sprint=None, issuetype=None, limit=LIMIT):
    """Open tickets with what each one is missing, most missing first."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE w.project_key IN $allowed AND w.summary IS NOT NULL
          AND coalesce(w.statusCategory, '') <> 'done'
          AND NOT toLower(coalesce(w.issuetype, '')) IN ['epic']
        """ + _FILTERS + """
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        WITH w, a, toLower(coalesce(w.issuetype, '')) AS t, trim(coalesce(w.description_text, '')) AS d,
             toLower(coalesce(w.custom_fields, '')) AS cf
        WITH w, a, [x IN [
               CASE WHEN size(d) < 20 THEN 'description' END,
               CASE WHEN a IS NULL THEN 'assignee' END,
               CASE WHEN t IN ['story', 'task'] AND NOT cf CONTAINS 'story point' THEN 'story points' END,
               CASE WHEN t = 'story' AND NOT (toLower(d) CONTAINS 'acceptance' OR d CONTAINS 'معايير القبول')
                    THEN 'acceptance criteria' END
             ] WHERE x IS NOT NULL] AS missing
        WHERE size(missing) > 0
        WITH w, a, missing ORDER BY size(missing) DESC, w.key
        WITH collect({key: w.key, summary: w.summary, type: w.issuetype, status: w.status, url: w.url,
                      assignee: coalesce(a.displayName, 'Unassigned'), missing: missing}) AS items
        RETURN size(items) AS total, items[0..$limit] AS items
        """,
        limit=limit, **_low(project=project, sprint=sprint, issuetype=issuetype), **_scope(ctx))
    return rows[0] if rows else {"total": 0, "items": []}


def _days_since(value, now):
    try:
        then = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if then.tzinfo is None:
        then = then.replace(tzinfo=timezone.utc)
    return (now - then).days


def stuck(ctx, project=None, sprint=None, issuetype=None, min_days=7, limit=LIMIT, now=None):
    """Open tickets that have been in their current status for at least min_days, longest first.
    The time is taken from the last status change, or the creation date when it never changed."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE w.project_key IN $allowed AND w.summary IS NOT NULL
          AND coalesce(w.statusCategory, '') <> 'done'
        """ + _FILTERS + """
        OPTIONAL MATCH (w)-[:HAD_CHANGE]->(c:ChangeEvent) WHERE toLower(c.field) = 'status'
        WITH w, max(c.changed_at) AS last_move
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        RETURN w.key AS key, w.summary AS summary, w.status AS status, w.url AS url,
               coalesce(a.displayName, 'Unassigned') AS assignee,
               coalesce(last_move, w.status_changed_at, w.created) AS since
        """,
        **_low(project=project, sprint=sprint, issuetype=issuetype), **_scope(ctx))
    now = now or datetime.now(timezone.utc)
    items = []
    for r in rows:
        days = _days_since(r["since"], now)
        if days is not None and days >= min_days:
            items.append({**r, "days": days})
    items.sort(key=lambda i: (-i["days"], i["key"]))
    return {"total": len(items), "items": items[:limit]}


# ---------- Sprints ----------
# A sprint is chosen by its id (uid), never by its name alone: two boards can each have a "Sprint 4".

ACTIVE_WORDS = {"active", "current", "open", "الحالي", "الحالية", "الشغال", "اللي شغال"}


def _same_name(wanted, name):
    """"sprint 4" is "SCRUM Sprint 4" but not "Sprint 40"."""
    wanted, name = " ".join(wanted.lower().split()), " ".join((name or "").lower().split())
    return wanted == name or bool(re.search(r"(?<![\w])" + re.escape(wanted) + r"(?![\w])", name))


def find_sprints(ctx, sprint, project=None):
    """The sprints a name (or "active") means in the allowed projects, best matches first, each with
    its uid, state, dates, board, how many tickets it has and in which projects. An exact name beats a
    partial one; among equals the active sprint, then the newest, comes first."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})-[:IN_SPRINT]->(s:Sprint)
        WHERE w.project_key IN $allowed AND ($project IS NULL OR toLower(w.project_key) = $project)
        RETURN s.uid AS uid, s.name AS name, s.state AS state, s.goal AS goal, s.startDate AS start,
               s.endDate AS end, s.completeDate AS completed, s.boardId AS board,
               count(DISTINCT w) AS n, collect(DISTINCT w.project_key) AS projects
        """, **_low(project=project), **_scope(ctx))
    wanted = " ".join(str(sprint or "").lower().split())
    if not wanted:
        return []
    if wanted in ACTIVE_WORDS:
        found = [dict(r) for r in rows if (r["state"] or "").lower() == "active"]
    else:
        exact = [dict(r) for r in rows if " ".join((r["name"] or "").lower().split()) == wanted]
        found = exact or [dict(r) for r in rows if _same_name(wanted, r["name"])]
    rank = {"active": 0, "future": 1, "closed": 2}
    found.sort(key=lambda r: str(r["start"] or ""), reverse=True)   # newest first, then by state
    return sorted(found, key=lambda r: rank.get((r["state"] or "").lower(), 3))


# ---------- Blockers ----------
# Jira link names differ per company ("Blocks", "Blocker", "Depends", "Dependency"...). The graph keeps
# each as a relationship type made from its outward name. The direction is read from the verb:
# "A blocks B" means A blocks B; "A is blocked by B", "A depends on B" or "A requires B" means B blocks A.

_BACKWARD = re.compile(r"blocked by|is blocked|depends|depend on|dependent|requires|waits? for|\bneeds\b")
_FORWARD = re.compile(r"block|dependency (?:of|for)|required by|needed by|prerequisite")


def blocking_types():
    """-> (forward, backward) relationship types of the graph that mean one ticket blocks another."""
    types = [r["t"] for r in run_query("CALL db.relationshipTypes() YIELD relationshipType AS t RETURN t")]
    forward, backward = [], []
    for t in types:
        words = t.lower().replace("_", " ")
        if _BACKWARD.search(words):
            backward.append(t)
        elif _FORWARD.search(words):
            forward.append(t)
    return forward, backward


def blockers(ctx, sprint_uid=None, project=None, key=None, include_done=False, limit=LIMIT):
    """Tickets with blocking links and the tickets that block them. A blocker is unresolved while it is
    not done. -> {"linked": tickets with any blocking link, "blocked": open tickets with an unresolved
    blocker, "items": those tickets, "types": the link types read}. A blocker outside the allowed
    projects is counted but never named."""
    forward, backward = blocking_types()
    if not forward and not backward:
        return {"linked": 0, "blocked": 0, "items": [], "types": []}
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE w.project_key IN $allowed AND ($project IS NULL OR toLower(w.project_key) = $project)
          AND ($key IS NULL OR w.key = $key)
          AND ($sprint IS NULL OR EXISTS { MATCH (w)-[:IN_SPRINT]->(:Sprint {uid: $sprint}) })
        CALL {
            WITH w
            OPTIONAL MATCH (b:WorkItem {tenant_id: $tenant})-[r]->(w) WHERE type(r) IN $forward
            RETURN collect(DISTINCT b) AS f
        }
        CALL {
            WITH w
            OPTIONAL MATCH (w)-[r]->(b:WorkItem {tenant_id: $tenant}) WHERE type(r) IN $backward
            RETURN collect(DISTINCT b) AS bk
        }
        WITH w, f + bk AS found
        WHERE size(found) > 0
        RETURN w.key AS key, w.summary AS summary, w.status AS status, w.statusCategory AS category,
               w.url AS url,
               [b IN found WHERE b.project_key IN $allowed | {key: b.key, summary: b.summary, status: b.status,
                    done: coalesce(b.statusCategory, '') = 'done', url: b.url}] AS by,
               size([b IN found WHERE NOT b.project_key IN $allowed AND coalesce(b.statusCategory, '') <> 'done']) AS hidden
        ORDER BY w.key
        """, forward=forward, backward=backward, sprint=sprint_uid, key=(key or "").upper() or None,
        **_low(project=project), **_scope(ctx))
    items = []
    for r in rows:
        r = dict(r)
        r["open_by"] = [b for b in r["by"] if not b["done"]]
        r["blocked"] = (r["category"] != DONE) and bool(r["open_by"] or r["hidden"])
        if r["blocked"] or include_done:
            items.append(r)
    return {"linked": len(rows), "blocked": sum(1 for r in items if r["blocked"]), "items": items[:limit],
            "types": forward + backward}


def sprint_summary(ctx, sprint, project=None, limit=LIMIT, now=None):
    """One sprint, chosen by uid: name, state, dates, goal, totals by status and status category,
    completion, its blocked tickets, overdue and unassigned open tickets, and the done and open tickets.
    -> None when no sprint matches; {"choices": [...]} when several sprints share the name."""
    found = find_sprints(ctx, sprint, project)
    if not found:
        return None
    best = [f for f in found if f["name"] == found[0]["name"] and f["state"] == found[0]["state"]]
    if len(best) > 1:
        return {"choices": found[:5]}
    chosen = found[0]
    rows = [dict(r) for r in run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})-[:IN_SPRINT]->(:Sprint {uid: $uid})
        WHERE w.project_key IN $allowed AND ($project IS NULL OR toLower(w.project_key) = $project)
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        OPTIONAL MATCH (w)-[:HAD_CHANGE]->(c:ChangeEvent)
          WHERE toLower(c.field) = 'status' AND c.to_name = w.status
        WITH w, a, c ORDER BY c.changed_at DESC
        WITH w, a, collect(c)[0] AS last
        RETURN w.key AS key, w.summary AS summary, w.status AS status, w.statusCategory AS category,
               w.issuetype AS type, w.url AS url, w.duedate AS due, coalesce(a.displayName, 'Unassigned') AS assignee,
               last.author AS moved_by, last.changed_at AS moved_at
        ORDER BY w.key
        """, uid=chosen["uid"], **_low(project=project), **_scope(ctx))]
    by_status, by_category = {}, {}
    for r in rows:
        by_status[r["status"] or "unknown"] = by_status.get(r["status"] or "unknown", 0) + 1
        by_category[r["category"] or "unknown"] = by_category.get(r["category"] or "unknown", 0) + 1
    done = [r for r in rows if r["category"] == DONE]
    open_ = [r for r in rows if r["category"] != DONE]
    today = (now or datetime.now(timezone.utc)).date().isoformat()
    try:
        blocked = blockers(ctx, sprint_uid=chosen["uid"], project=project, limit=limit)
    except Exception:   # the summary still stands without the links
        blocked = None
    return {"sprint": chosen, "other_matches": [f for f in found[1:4]], "total": len(rows),
            "by_status": dict(sorted(by_status.items(), key=lambda kv: -kv[1])), "by_category": by_category,
            "completion": round(100 * len(done) / len(rows)) if rows else 0,
            "blocked": blocked, "overdue": [r for r in open_ if r["due"] and str(r["due"])[:10] < today][:limit],
            "unassigned": sum(1 for r in open_ if r["assignee"] == "Unassigned"),
            "done": done[:limit], "open": open_[:limit]}


def uncovered_requirements(ctx, project=None, kinds=("requirement", "action_item"), limit=LIMIT):
    """Approved meeting items of the given kinds that mention no Jira ticket, newest meeting first."""
    rows = run_query(
        """
        MATCH (s:Source {tenant_id: $tenant, status: 'approved'})-[:HAS_ITEM]->(i:MeetingItem {status: 'approved'})
        WHERE s.project_key IN $allowed AND ($project IS NULL OR toLower(s.project_key) = $project)
          AND i.type IN $kinds
          AND NOT EXISTS { MATCH (i)-[:MENTIONS]->(w:WorkItem) WHERE w.project_key IN $allowed }
        WITH s, i ORDER BY coalesce(s.meeting_date, '') DESC, i.uid
        WITH collect({type: i.type, text: i.text, owner: i.owner, due: i.due, title: s.title,
                      date: s.meeting_date, project: s.project_key}) AS items
        RETURN size(items) AS total, items[0..$limit] AS items
        """, kinds=list(kinds), limit=limit, **_low(project=project), **_scope(ctx))
    return rows[0] if rows else {"total": 0, "items": []}


# ---------- Tags in titles ----------
# Teams write the area of a ticket in its title: "Backend: ...", "[AI] ...", "... (Flutter)". The
# words differ per company, so none is named here: the tag is whatever short text sits in that place.
# Labels and components count as tags too.

_PREFIX = re.compile(r"^\s*[\[(]?\s*([^\[\]():|\-–]{1,30}?)\s*[\])]?\s*[:|]\s+\S")
_BRACKET_START = re.compile(r"^\s*[\[(]\s*([^\[\]()]{1,30}?)\s*[\])]")
_BRACKET_END = re.compile(r"[\[(]\s*([^\[\]()]{1,30}?)\s*[\])]\s*$")
MAX_TAG_WORDS = 3
TAGGED_TICKETS = 3000


def title_tags(summary):
    """Tags written in a title: a short prefix before ":" and text in brackets at either end."""
    found = []
    summary = (summary or "").strip().strip('"\'“”')   # some exports wrap titles in quotes
    for pattern in (_PREFIX, _BRACKET_START, _BRACKET_END):
        m = pattern.search(summary)
        if m:
            tag = " ".join(m.group(1).split()).lower()
            if tag and len(tag.split()) <= MAX_TAG_WORDS and not any(ch.isdigit() for ch in tag):
                found.append(tag)
    return list(dict.fromkeys(found))


def ticket_tags(summary, labels=None, components=None):
    tags = title_tags(summary) + [str(x).lower() for x in (labels or []) + (components or []) if x]
    return list(dict.fromkeys(tags))


def _same_tag(wanted, tag):
    """"flutter" matches "flutter-web" and "Flutter Web"; "ai" matches "ai" but not "email"."""
    norm = lambda t: re.sub(r"[\s_\-]+", " ", t.lower()).strip()
    a, b = norm(wanted), norm(tag)
    return a == b or b.split(" ")[0] == a or a.split(" ")[0] == b


def _tagged(ctx, project=None, sprint=None, parent=None, status=None):
    low = _low(project=project, sprint=sprint, issuetype=None)
    rows = [dict(r) for r in run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE w.project_key IN $allowed AND w.summary IS NOT NULL
          AND ($status IS NULL OR toLower(w.status) CONTAINS $status OR toLower(w.statusCategory) = $status
               OR ($status = 'open' AND coalesce(w.statusCategory, '') <> 'done'))
          AND ($parent IS NULL OR EXISTS { MATCH (w)-[:CHILD_OF]->(p:WorkItem) WHERE p.key = $parent })
        """ + _FILTERS + """
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        OPTIONAL MATCH (w)-[:CHILD_OF]->(par:WorkItem)
        RETURN w.key AS key, w.summary AS summary, w.issuetype AS type, w.status AS status,
               w.statusCategory AS category, w.priority AS priority, w.url AS url, w.labels AS labels, w.components AS components,
               coalesce(a.displayName, 'Unassigned') AS assignee, par.key AS parent,
               par.summary AS parent_summary, par.labels AS parent_labels, par.components AS parent_components
        ORDER BY w.key LIMIT $limit
        """, parent=(parent or "").strip().upper() or None, status=(status or "").strip().lower() or None,
        limit=TAGGED_TICKETS, **low, **_scope(ctx))]   # dicts: a Neo4j record can't take the tags
    for r in rows:
        # A subtask with no tag of its own belongs to its parent's team or area.
        r["tags"] = ticket_tags(r["summary"], r.get("labels"), r.get("components")) or \
            ticket_tags(r.get("parent_summary"), r.get("parent_labels"), r.get("parent_components"))
    return rows


def tickets_by_tag(ctx, tag, project=None, sprint=None, parent=None, status=None, limit=LIMIT):
    """Tickets whose title tag, label or component is this tag, such as the backend subtasks of a story."""
    rows = [r for r in _tagged(ctx, project, sprint, parent, status) if any(_same_tag(tag, t) for t in r["tags"])]
    return {"total": len(rows), "items": rows[:limit]}


def _group(tag):
    """"flutter-web", "Flutter Web" and "flutter" count as one area."""
    return re.sub(r"[\s_\-]+", " ", tag.lower()).strip().split(" ")[0]


def tag_overview(ctx, project=None, sprint=None, parent=None):
    """Open and done tickets per tag, most open first. A ticket counts once per area."""
    counts = {}
    for r in _tagged(ctx, project, sprint, parent):
        for t in dict.fromkeys(_group(x) for x in r["tags"]):
            c = counts.setdefault(t, {"tag": t, "open": 0, "done": 0})
            c["done" if r["category"] == DONE else "open"] += 1
    return sorted(counts.values(), key=lambda c: (-c["open"], -c["done"], c["tag"]))


# ---------- Worklogs, estimates and activity ----------

def _hours(seconds):
    return round((seconds or 0) / 3600, 2)


def worklog_details(ctx, key, author=None, limit=LIMIT):
    """One ticket's time: estimate, remaining, total spent, per person, and the latest entries with
    their date and text. Jira's own "time spent" and the sum of the worklogs can differ (a log can be
    deleted or the field set by hand), so both are given."""
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE (w.key = $key OR $key IN coalesce(w.key_aliases, [])) AND w.project_key IN $allowed
        OPTIONAL MATCH (w)-[:HAS_WORKLOG]->(l:Worklog)
        OPTIONAL MATCH (l)-[:LOGGED_BY]->(p:Person)
        WITH w, l, coalesce(p.displayName, 'Unknown') AS author
        WHERE l IS NULL OR $author IS NULL OR toLower(author) CONTAINS $author
        WITH w, l, author ORDER BY l.started DESC
        RETURN w.key AS key, w.original_estimate_seconds AS estimate, w.remaining_estimate_seconds AS remaining,
               w.time_spent_seconds AS spent, w.worklog_total AS jira_total,
               collect(CASE WHEN l IS NULL THEN NULL ELSE {author: author, seconds: l.timeSpentSeconds,
                       started: l.started, text: l.text} END) AS logs
        """, key=key.upper(), author=(author or "").strip().lower() or None, **_scope(ctx))
    if not rows:
        return None
    r = rows[0]
    logs = [x for x in r["logs"] if x]
    people = {}
    for x in logs:
        people[x["author"]] = people.get(x["author"], 0) + (x["seconds"] or 0)
    return {"key": r["key"], "estimate_h": _hours(r["estimate"]) if r["estimate"] is not None else None,
            "remaining_h": _hours(r["remaining"]) if r["remaining"] is not None else None,
            "spent_h": _hours(r["spent"]) if r["spent"] is not None else None,
            "logged_h": _hours(sum(people.values())), "entries": len(logs),
            "missing_entries": max(0, (r["jira_total"] or 0) - len(logs)) if not author else 0,
            "people": sorted(((a, _hours(s)) for a, s in people.items()), key=lambda x: -x[1]),
            "latest": logs[:limit]}


def over_estimate(ctx, project=None, sprint=None, assignee=None, limit=LIMIT):
    """Tickets whose time spent is more than their original estimate, most over first."""
    low = _low(project=project, sprint=sprint, issuetype=None)
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE w.project_key IN $allowed AND coalesce(w.original_estimate_seconds, 0) > 0
        """ + _FILTERS + """
        OPTIONAL MATCH (w)-[:HAS_WORKLOG]->(l:Worklog)
        WITH w, sum(coalesce(l.timeSpentSeconds, 0)) AS logged
        WITH w, CASE WHEN coalesce(w.time_spent_seconds, 0) > logged THEN w.time_spent_seconds ELSE logged END AS spent
        WHERE spent > w.original_estimate_seconds
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        WITH w, spent, a WHERE $assignee IS NULL OR toLower(a.displayName) CONTAINS $assignee
        RETURN w.key AS key, w.summary AS summary, w.status AS status, w.url AS url,
               coalesce(a.displayName, 'Unassigned') AS assignee,
               w.original_estimate_seconds AS estimate, spent
        ORDER BY spent - w.original_estimate_seconds DESC, w.key LIMIT $limit
        """, assignee=(assignee or "").strip().lower() or None, limit=limit, **low, **_scope(ctx))
    return [{**r, "estimate_h": _hours(r["estimate"]), "spent_h": _hours(r["spent"]),
             "over_h": _hours(r["spent"] - r["estimate"])} for r in rows]


def activity(ctx, person, since=None, until=None, limit=40):
    """What one person did, newest first: status and other field changes, comments and time logged,
    each with its ticket. since and until are dates (YYYY-MM-DD); until is the day after the period."""
    rows = run_query(
        """
        MATCH (p:Person) WHERE p.tenant_id = $tenant AND p.displayName = $person
        CALL {
          WITH p
          MATCH (w:WorkItem {tenant_id: $tenant})-[:HAD_CHANGE]->(c:ChangeEvent)-[:CHANGED_BY]->(p)
          WHERE w.project_key IN $allowed
          RETURN c.changed_at AS at, 'change' AS kind, w.key AS key, w.summary AS summary, w.url AS url,
                 c.field + ': ' + coalesce(c.from_name, '-') + ' -> ' + coalesce(c.to_name, '-') AS what
          UNION
          WITH p
          MATCH (w:WorkItem {tenant_id: $tenant})-[:HAS_COMMENT]->(c:Comment)-[:WRITTEN_BY]->(p)
          WHERE w.project_key IN $allowed
          RETURN c.created AS at, 'comment' AS kind, w.key AS key, w.summary AS summary, w.url AS url,
                 left(coalesce(c.text, ''), 200) AS what
          UNION
          WITH p
          MATCH (w:WorkItem {tenant_id: $tenant})-[:HAS_WORKLOG]->(l:Worklog)-[:LOGGED_BY]->(p)
          WHERE w.project_key IN $allowed
          RETURN l.started AS at, 'worklog' AS kind, w.key AS key, w.summary AS summary, w.url AS url,
                 coalesce(l.timeSpent, toString(round(coalesce(l.timeSpentSeconds, 0) / 36.0) / 100.0) + 'h')
                 + coalesce(' - ' + left(l.text, 150), '') AS what
        }
        WITH at, kind, key, summary, url, what
        WHERE at IS NOT NULL AND ($since IS NULL OR at >= $since) AND ($until IS NULL OR at < $until)
        RETURN at, kind, key, summary, url, what ORDER BY at DESC LIMIT $limit
        """, person=person, since=since, until=until, limit=limit, **_scope(ctx))
    return rows
