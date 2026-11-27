"""
meetings/memory.py
The project's requirements and their story across meetings: what the client asked first, what later
meetings changed, dropped or brought back, and who edited the wording.

  (:Requirement {uid, tenant_id, project_key, text, status: active|dropped, created_at, updated_at})
  (:Requirement)-[:HAS_CHANGE]->(:Change {type, before, after, note, quote, lines, at, ...})
  (:Change)-[:FROM_MEETING]->(:Source)          not for "edited" (a team member, not a meeting)
  (:MeetingItem)-[:ABOUT]->(:Requirement)        every approved item that speaks about it

Change types: created | modified | clarified | dropped | restored | edited.
The memory changes only when a source is approved, from approved items, so nothing unreviewed enters
it. Deleting a meeting removes the changes it made; a requirement with no change left is deleted, the
others are replayed from what remains. Same rules as Jira data: hard delete, no tombstone.
"""
import hashlib
import re

CHANGE_TYPES = ("created", "modified", "clarified", "dropped", "restored", "edited")
TRACKED_ITEMS = ("requirement", "decision")   # a decision can change or drop a requirement
STOP = {"the", "a", "an", "to", "of", "and", "or", "in", "on", "for", "with", "is", "be", "it", "that",
        "what", "did", "does", "about", "client", "say", "said", "meeting", "requirement", "requirements"}


def requirement_uid(tenant, item_uid):
    return f"{tenant}:req:{hashlib.sha256(item_uid.encode()).hexdigest()[:16]}"


def change_uid(req_uid, item_uid, kind):
    return f"{req_uid}:chg:{hashlib.sha256(f'{item_uid}:{kind}'.encode()).hexdigest()[:12]}"


def replay(changes):
    """-> (text, status) after the changes, oldest first. The first change left counts as the start
    even when the meeting that created the requirement was deleted."""
    text, status = None, "active"
    for n, c in enumerate(sorted(changes, key=lambda c: (c.get("at") or "", c.get("order") or 0))):
        kind = c["type"]
        if n == 0 or kind in ("created", "modified", "clarified", "edited", "restored"):
            text = c.get("after") or text
        if kind == "dropped":
            status = "dropped"
        elif kind in ("created", "restored") or n == 0:
            status = "active"
    return text, status


def plan_changes(item, earlier_reqs):
    """What one approved item does to the memory. `earlier_reqs` are the requirements of the earlier
    items the comparison pointed to: [{uid, text, status}].
    -> list of (action, requirement uid or None, change type)."""
    relation = item.get("relation")
    targets = [r for r in earlier_reqs if r.get("uid")]
    if relation == "dropped" and targets:
        return [("update", r["uid"], "dropped") for r in targets if r.get("status") != "dropped"]
    if relation in ("change", "conflict") and targets:
        return [("update", r["uid"], "restored" if r.get("status") == "dropped" else "modified") for r in targets]
    if relation == "existing" and targets:
        return [("update", r["uid"], "restored") if r.get("status") == "dropped" else ("link", r["uid"], None)
                for r in targets]
    if item.get("type") == "requirement":
        return [("create", None, "created")]
    return []


def _create(tx, req_uid, tenant, project, text, at):
    tx.run("MERGE (r:Requirement {uid: $uid}) ON CREATE SET r.tenant_id = $tenant, "
           "r.project_key = $project, r.created_at = $at, r.text = $text, r.status = 'active' "
           "SET r.updated_at = $at", uid=req_uid, tenant=tenant, project=project, at=at, text=text)


def _change(tx, req_uid, source_uid, item, kind, before, after, at, order, tenant, project):
    tx.run(
        """
        MATCH (r:Requirement {uid: $req}), (s:Source {uid: $source})
        MERGE (c:Change {uid: $uid})
        SET c += {tenant_id: $tenant, project_key: $project, type: $kind, before: $before, after: $after,
                  note: $note, quote: $quote, lines: $lines, at: $at, order: $order,
                  source_uid: $source, item_uid: $item}
        MERGE (r)-[:HAS_CHANGE]->(c)
        MERGE (c)-[:FROM_MEETING]->(s)
        """, req=req_uid, source=source_uid, uid=change_uid(req_uid, item["uid"], kind), tenant=tenant,
        project=project, kind=kind, before=before, after=after, note=item.get("relation_note"),
        quote=item.get("evidence"), lines=item.get("lines") or [], at=at, order=order, item=item["uid"])


def apply_approved(tx, source_uid, tenant, project):
    """Bring the approved items of a just-approved source into the memory (same transaction).

    An earlier item this meeting changes, drops or confirms may have no requirement yet (it was approved
    before the memory existed, or it was a decision such as "release notes in English only"): its
    requirement is created first, from that earlier meeting, so the story starts where it was said."""
    rows = list(tx.run(
        """
        MATCH (s:Source {uid: $uid})-[:HAS_ITEM]->(i:MeetingItem {status: 'approved'})
        WHERE i.type IN $types
        OPTIONAL MATCH (i)-[:RELATES_TO]->(e:MeetingItem)<-[:HAS_ITEM]-(es:Source)
        WHERE e.type IN $types AND e.tenant_id = $tenant
        OPTIONAL MATCH (e)-[:ABOUT]->(r:Requirement {tenant_id: $tenant})
        WITH s, i, collect(DISTINCT r {.uid, .text, .status}) AS reqs,
             collect(DISTINCT CASE WHEN r IS NULL AND e IS NOT NULL THEN
                     e {.uid, .type, .text, .evidence, .lines, source: es.uid, at: es.meeting_date} END) AS orphans
        RETURN i {.uid, .type, .text, .evidence, .lines, .relation, .relation_note} AS item,
               s.meeting_date AS at, reqs, orphans
        ORDER BY item.uid
        """, uid=source_uid, types=list(TRACKED_ITEMS), tenant=tenant))
    for order, row in enumerate(rows):
        item, at = dict(row["item"]), row["at"]
        reqs = {r["uid"]: dict(r) for r in row["reqs"] if r and r.get("uid")}
        if item.get("relation") in ("change", "conflict", "dropped", "existing"):
            for orphan in (dict(o) for o in row["orphans"] if o):
                req_uid = requirement_uid(tenant, orphan["uid"])
                _create(tx, req_uid, tenant, project, orphan["text"], orphan["at"])
                tx.run("MATCH (e:MeetingItem {uid: $item}), (r:Requirement {uid: $req}) MERGE (e)-[:ABOUT]->(r)",
                       item=orphan["uid"], req=req_uid)
                _change(tx, req_uid, orphan["source"], orphan, "created", None, orphan["text"], orphan["at"], 0,
                        tenant, project)
                _refresh(tx, req_uid)
                reqs[req_uid] = {"uid": req_uid, "text": orphan["text"], "status": "active"}
        for action, req_uid, kind in plan_changes(item, list(reqs.values())):
            if action == "create":
                req_uid = requirement_uid(tenant, item["uid"])
                _create(tx, req_uid, tenant, project, item["text"], at)
                before = None
            else:
                before = reqs[req_uid]["text"]
            tx.run("MATCH (i:MeetingItem {uid: $item}), (r:Requirement {uid: $req}) MERGE (i)-[:ABOUT]->(r)",
                   item=item["uid"], req=req_uid)
            if action == "link":
                continue
            after = before if kind == "dropped" else item["text"]
            _change(tx, req_uid, source_uid, item, kind, before, after, at, order, tenant, project)
            _refresh(tx, req_uid)


def apply_answers(tx, source_uid):
    """An approved item that answers an earlier open question: (answer)-[:ANSWERS]->(question). The
    question counts as answered while that link exists; deleting the answering meeting deletes its items
    and so the link, and the question is open again."""
    tx.run("""
        MATCH (:Source {uid: $uid})-[:HAS_ITEM]->(a:MeetingItem {status: 'approved', relation: 'answers'})
              -[:RELATES_TO]->(q:MeetingItem {type: 'open_question'})
        WHERE q.tenant_id = a.tenant_id
        MERGE (a)-[:ANSWERS]->(q)
        """, uid=source_uid)


def open_questions(ctx, run_query, project=None, limit=30):
    """Approved open questions no later approved item answers, newest meeting first, with where they
    were asked: what to raise in the next meeting."""
    rows = run_query(
        """
        MATCH (s:Source {tenant_id: $tenant, status: 'approved'})-[:HAS_ITEM]->
              (q:MeetingItem {type: 'open_question', status: 'approved'})
        WHERE s.project_key IN $allowed AND ($project IS NULL OR s.project_key = $project)
              AND NOT EXISTS { MATCH (:MeetingItem {status: 'approved'})-[:ANSWERS]->(q) }
        RETURN q.uid AS uid, q.text AS text, q.evidence AS quote, s.title AS meeting, s.meeting_date AS date,
               s.project_key AS project
        ORDER BY s.meeting_date DESC LIMIT $limit
        """, tenant=ctx.tenant_id, allowed=list(ctx.allowed_projects), project=project, limit=limit)
    return [dict(r) for r in rows]


def _refresh(tx, req_uid):
    """Replay a requirement's changes into its current text and status; delete it when none are left."""
    changes = [dict(c) for c in tx.run("MATCH (:Requirement {uid: $uid})-[:HAS_CHANGE]->(c:Change) "
                                       "RETURN c {.type, .after, .at, .order} AS c", uid=req_uid).value("c")]
    if not changes:
        tx.run("MATCH (r:Requirement {uid: $uid}) DETACH DELETE r", uid=req_uid)
        return
    text, status = replay(changes)
    last = max(c.get("at") or "" for c in changes)
    tx.run("MATCH (r:Requirement {uid: $uid}) SET r.text = $text, r.status = $status, r.updated_at = $at",
           uid=req_uid, text=text, status=status, at=last)


def forget_source(tx, source_uid):
    """Before a meeting is deleted: remove the changes it made and replay what they touched."""
    touched = tx.run("MATCH (c:Change)-[:FROM_MEETING]->(:Source {uid: $uid}) "
                     "MATCH (r:Requirement)-[:HAS_CHANGE]->(c) RETURN collect(DISTINCT r.uid) AS reqs",
                     uid=source_uid).single()["reqs"]
    tx.run("MATCH (c:Change)-[:FROM_MEETING]->(:Source {uid: $uid}) DETACH DELETE c", uid=source_uid)
    for req_uid in touched:
        _refresh(tx, req_uid)


def edit(tx, ctx, req_uid, text, by, at):
    """A team member rewords a requirement: an "edited" change, with who, and no meeting."""
    row = tx.run("MATCH (r:Requirement {uid: $uid, tenant_id: $tenant}) WHERE r.project_key IN $allowed "
                 "RETURN r.text AS text, r.project_key AS project", uid=req_uid, tenant=ctx.tenant_id,
                 allowed=list(ctx.allowed_projects)).single()
    if not row:
        return False
    tx.run("""
        MATCH (r:Requirement {uid: $req})
        CREATE (c:Change {uid: $uid, tenant_id: $tenant, project_key: $project, type: 'edited', before: $before,
                          after: $after, by: $by, at: $at, order: 0})
        MERGE (r)-[:HAS_CHANGE]->(c)
        """, req=req_uid, uid=f"{req_uid}:chg:edit:{at}", tenant=ctx.tenant_id, project=row["project"],
           before=row["text"], after=text, by=by, at=at)
    _refresh(tx, req_uid)
    return True


def _words(text):
    return {w for w in re.findall(r"\w+", (text or "").lower()) if len(w) > 2 and w not in STOP}


def history(ctx, run_query, question=None, project=None, limit=5):
    """The requirements the question is about (all, newest first, without one) with their story,
    oldest change first, each with its meeting's title and date."""
    rows = run_query(
        """
        MATCH (r:Requirement {tenant_id: $tenant}) WHERE r.project_key IN $allowed
              AND ($project IS NULL OR r.project_key = $project)
        OPTIONAL MATCH (r)-[:HAS_CHANGE]->(c:Change)
        OPTIONAL MATCH (c)-[:FROM_MEETING]->(s:Source)
        WITH r, c, s ORDER BY c.at, c.order
        RETURN r {.uid, .text, .status, .project_key, .updated_at} AS req,
               collect(CASE WHEN c IS NULL THEN NULL ELSE c {.type, .before, .after, .note, .quote, .lines, .at, .by,
                       meeting: s.title, meeting_date: s.meeting_date} END) AS changes
        """, tenant=ctx.tenant_id, allowed=list(ctx.allowed_projects), project=project)
    found = [{**dict(r["req"]), "changes": [dict(c) for c in r["changes"] if c]} for r in rows]
    wanted = _words(question)
    if wanted:
        def score(req):
            said = " ".join([req["text"] or ""] + [(c.get("before") or "") + " " + (c.get("after") or "") + " " +
                                                   (c.get("quote") or "") for c in req["changes"]])
            return len(wanted & _words(said))
        found = [r for r in found if score(r)]
        found.sort(key=lambda r: (score(r), r.get("updated_at") or ""), reverse=True)
    else:
        found.sort(key=lambda r: r.get("updated_at") or "", reverse=True)
    return found[:limit]


VERBS = {"created": "asked for", "modified": "changed it to", "clarified": "clarified it as",
         "dropped": "dropped it", "restored": "brought it back as", "edited": "reworded it as"}


def history_context(reqs):
    """Lines for the assistant, oldest first, so it can tell the story in order."""
    if not reqs:
        return "No requirement history matches."
    lines = ["Requirement history across meetings (oldest change first):"]
    for r in reqs:
        lines.append(f'Requirement [{r["status"]}] now: "{r["text"]}" (project {r["project_key"]})')
        for c in r["changes"]:
            who = f'{c["meeting"] or "untitled meeting"} ({c["meeting_date"]})' if c.get("meeting") or c.get("meeting_date") \
                else f'a team member ({c.get("by") or "unknown"}, {str(c.get("at") or "")[:10]})'
            what = VERBS.get(c["type"], c["type"])
            after = "" if c["type"] == "dropped" else f' "{c.get("after")}"'
            quote = f' | said: "{c["quote"][:200]}"' if c.get("quote") else ""
            note = f' | {c["note"]}' if c.get("note") else ""
            lines.append(f"  - {who}: {what}{after}{quote}{note}")
    return "\n".join(lines)
