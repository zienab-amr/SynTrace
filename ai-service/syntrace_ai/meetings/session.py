"""
meetings/session.py
The live meeting helper. During the meeting the app sends the transcript so far, as often as it likes;
each call reads only the lines it has not seen, next to what the project already knows (the requirement
memory and the questions earlier meetings left open), and returns only help it has not given before:

  ask_client   a question to ask now, because what the client just said is unclear or incomplete
  missing      the client asked for something but a detail needed to build it was not said or asked
  conflict     what is said now contradicts a requirement from an earlier meeting (says which, when)
  reminder     the talk touches a question an earlier meeting left open: a good moment to ask it
  risk         something said now that will be hard to build as said (scope, time, cost), neutral wording
  unverified   the client relies on an agreement, a promise or a delivered state that nothing on record
               shows (no meeting, ticket or pull request): confirm it before building on it

Besides the meeting memory, the project's facts are read for what the new lines talk about: the Jira
tickets that match them (with their status) and the pull requests of those tickets. A conflict may then
point at a ticket or a pull request too ("the client says login is done; Jira shows In Progress").

A question typed by the team ("did they say which payment methods?") is answered from the transcript so
far and the project memory only. At the end, the questions not asked yet and the project's open
questions become the list for the next meeting. Before ending, wrap_up reads the whole meeting once and
lists everything still not covered, so the team asks it now instead of calling the client again. The
whole transcript can then go through the usual
after-meeting pipeline (extraction, review, approval).

Rules checked by code, not trusted to the model: a quote must be in the transcript, a reference must be
one we gave, blame about a person is refused, and the same help is never returned twice. The session is
read-only: nothing is written to Jira or to the project's memory until a meeting is reviewed and approved.

Nothing here imports the graph or the web: the store (run_query) and the model (llm) are passed in.
"""
import hashlib
import json
import logging
from datetime import datetime, timezone

from syntrace_ai.meetings import text as tx
from syntrace_ai.meetings.errors import MeetingError
from syntrace_ai.meetings.prompts import SESSION_PROMPT, SPOKEN_NOTE, WRAP_UP_PROMPT

log = logging.getLogger("syntrace.meetings.session")

KINDS = ("ask_client", "missing", "conflict", "reminder", "risk", "unverified")
FACT_TYPES = ("ticket", "pull_request")
LIVE, ENDED = "live", "ended"
NEW_CHARS = 6000           # the newest part read per call (Groq: about 8K tokens per request)
CONTEXT_LINES = 8          # earlier lines shown before the new part, so a reply makes sense
MAX_SUGGESTIONS = 5        # per call
MAX_KEPT = 200             # per session
MEMORY_REQUIREMENTS = 6
MEMORY_QUESTIONS = 8
MEMORY_FACTS = 8           # tickets and pull requests about what was just said
MAX_WRAP_UP = 8
WRAP_UP_CHARS = 400_000    # the whole meeting: the wrap-up runs on the long-context model


def _now():
    return datetime.now(timezone.utc).isoformat()


def session_uid(tenant, session_id):
    return f"{tenant}:live:{session_id}"


def _key(kind, text):
    return hashlib.sha256(f"{kind}:{tx.normalize(text)}".encode()).hexdigest()[:16]


# ---------- pure parts ----------

def new_part(transcript, seen):
    """-> (first new line number (1-based), the new lines, earlier context lines, all lines). A transcript
    shorter than what was seen means the app restarted it: read it from the start."""
    lines = (transcript or "").split("\n")
    if seen > len(lines):
        seen = 0
    # The last line may still be being spoken (the speech-to-text adds to it): it is read now, but not
    # counted as seen, so the next call reads it again whole instead of skipping its end.
    ready = len(lines) - 1 if lines[-1].strip() else len(lines)
    new = lines[seen:]
    while new and sum(len(line) + 1 for line in new) > NEW_CHARS:   # keep the newest part
        new.pop(0)
        seen += 1
    return seen + 1, new, lines[max(0, seen - CONTEXT_LINES):seen], lines[:ready]


def numbered(lines, first):
    return "\n".join(f"{first + n}: {line}" for n, line in enumerate(lines))


def memory_block(requirements, questions, facts=()):
    """The project's memory as references the model may cite: R1.. requirements, Q1.. open questions,
    T1.. Jira tickets and pull requests about what was just said."""
    refs, lines = {}, []
    for n, r in enumerate(requirements[:MEMORY_REQUIREMENTS], 1):
        label = f"R{n}"
        first = next((c for c in r.get("changes") or [] if c.get("meeting")), None)
        where = f'{first["meeting"]} ({first["meeting_date"]})' if first else "an earlier meeting"
        refs[label] = {"type": "requirement", "uid": r["uid"], "text": r["text"], "status": r.get("status"),
                       "where": where}
        lines.append(f'{label}: [{r.get("status", "active")}] "{r["text"]}" (first asked in {where})')
    for n, q in enumerate(questions[:MEMORY_QUESTIONS], 1):
        label = f"Q{n}"
        where = f'{q.get("meeting") or "untitled meeting"} ({q.get("date")})'
        refs[label] = {"type": "open_question", "uid": q["uid"], "text": q["text"], "where": where}
        lines.append(f'{label}: open question from {where}: "{q["text"]}"')
    for n, f in enumerate([f for f in facts or () if f.get("type") in FACT_TYPES][:MEMORY_FACTS], 1):
        label = f"T{n}"
        what = f'Jira ticket {f["key"]}' if f["type"] == "ticket" else \
            f'pull request {f["key"]}' + (f' for {f["ticket"]}' if f.get("ticket") else "")
        refs[label] = {"type": f["type"], "uid": f["key"], "text": f.get("text") or "", "where": what,
                       "status": f.get("status")}
        lines.append(f'{label}: {what} [{f.get("status") or "unknown"}] "{f.get("text") or ""}"')
    return refs, "\n".join(lines) or "none"


def parse(reply):
    reply = (reply or "").rsplit("</think>", 1)[-1]
    start, end = reply.find("{"), reply.rfind("}")
    if start < 0 or end < start:
        return {}
    try:
        data = json.loads(reply[start:end + 1])
    except ValueError:
        return {}
    return data if isinstance(data, dict) else {}


def check(rows, transcript, refs, known, limit=MAX_SUGGESTIONS):
    """Keep the suggestions whose quote is in the transcript and whose reference we gave, without blame,
    and not given before. -> list of clean suggestions."""
    index = tx.evidence_index(transcript)
    kept = []
    for row in rows if isinstance(rows, list) else []:
        if not isinstance(row, dict) or row.get("kind") not in KINDS:
            continue
        kind, text = row["kind"], tx.clean_text(row.get("text"), 300)
        if not text or tx.blames_a_person(text):
            continue
        quote = tx.clean_text(row.get("quote"), tx.MAX_EVIDENCE_CHARS)
        if quote and not tx.evidence_found(quote, index):
            fixed = tx.repair_evidence(quote, transcript)
            quote = fixed if fixed and tx.evidence_found(fixed, index) else None
        if quote and tx.blames_a_person(quote):
            continue
        ref = row.get("ref") if row.get("ref") in refs else None
        if kind in ("ask_client", "missing", "risk", "conflict", "unverified") and not quote:
            continue   # help about what was said must point at what was said
        if kind == "conflict" and (not ref or refs[ref]["type"] not in ("requirement",) + FACT_TYPES):
            continue
        if kind == "unverified" and ref and refs[ref]["type"] != "open_question":
            ref = None   # "not on record" points at nothing on record
        if kind == "reminder" and (not ref or refs[ref]["type"] != "open_question"):
            continue
        key = _key(kind, text)
        if key in known:
            continue
        known.add(key)
        kept.append({"id": key, "kind": kind, "text": text, "quote": quote,
                     "lines": tx.evidence_lines(quote, transcript) if quote else [],
                     "ref": dict(refs[ref], label=ref) if ref else None})
        if len(kept) >= limit:
            break
    return kept


def answer_text(data, transcript):
    """The answer to the team's question, with its quote checked; a quote not in the transcript is dropped."""
    answer = tx.clean_text(data.get("answer"), 800)
    if not answer:
        return None
    quote = tx.clean_text(data.get("answer_quote"), tx.MAX_EVIDENCE_CHARS)
    if quote and not tx.evidence_found(quote, tx.evidence_index(transcript)):
        quote = None
    return {"text": answer, "quote": quote, "lines": tx.evidence_lines(quote, transcript) if quote else []}


# ---------- the service ----------

class LiveSessions:
    """Start, assist and end live sessions. `run_query` is the graph port, `llm` a prompt -> reply
    function, `history` and `open_questions` read the project's memory, `submit` starts the usual
    after-meeting pipeline."""

    def __init__(self, run_query, llm, history, open_questions, submit=None, wrap_llm=None, facts=None):
        self.run_query, self.llm, self.wrap_llm = run_query, llm, wrap_llm or llm
        self.history, self.open_questions, self.submit = history, open_questions, submit
        self.facts = facts   # (ctx, text, project) -> tickets and pull requests about the text

    def _facts(self, ctx, text, project):
        if not self.facts or not text.strip():
            return []
        try:
            return self.facts(ctx, text, project) or []
        except Exception as exc:   # no facts is no reason to stop helping
            log.warning("live project facts unavailable: %s", type(exc).__name__)
            return []

    def _load(self, ctx, session_id):
        rows = self.run_query(
            "MATCH (l:LiveSession {uid: $uid, tenant_id: $tenant}) WHERE l.project_key IN $allowed "
            "RETURN l {.*} AS l", uid=session_uid(ctx.tenant_id, session_id), tenant=ctx.tenant_id,
            allowed=list(ctx.allowed_projects))
        if not rows:
            raise MeetingError("live session not found", 404)
        return dict(rows[0]["l"])

    def start(self, ctx, session_id, project, title=None, started_by=None):
        project = (project or "").strip().upper()
        if project not in ctx.allowed_projects:
            raise MeetingError("project is not in the allowed projects", 403)
        self.run_query(
            "MERGE (l:LiveSession {uid: $uid}) "
            "ON CREATE SET l.tenant_id = $tenant, l.project_key = $project, l.session_id = $sid, l.title = $title, "
            "l.started_by = $by, l.started_at = $at, l.status = $live, l.lines_seen = 0, l.suggestions = [], "
            "l.keys = [], l.dismissed = []",
            uid=session_uid(ctx.tenant_id, session_id), tenant=ctx.tenant_id, project=project, sid=session_id,
            title=(title or "").strip()[:300] or None, by=started_by, at=_now(), live=LIVE)
        return self.view(ctx, session_id)

    def view(self, ctx, session_id):
        s = self._load(ctx, session_id)
        given = [json.loads(x) for x in s.get("suggestions") or []]
        dismissed = set(s.get("dismissed") or [])
        return {"session_id": s["session_id"], "project": s["project_key"], "title": s.get("title"),
                "status": s["status"], "lines_seen": s.get("lines_seen") or 0, "started_at": s.get("started_at"),
                "suggestions": [dict(g, done=g["id"] in dismissed) for g in given],
                "source_id": s.get("source_id")}

    def assist(self, ctx, session_id, transcript, question=None, dismiss=()):
        """Read the new lines and return only new help (and the answer to `question`, when asked)."""
        s = self._load(ctx, session_id)
        if s["status"] != LIVE:
            raise MeetingError("this live session has ended", 409)
        transcript = tx.mask_sensitive(transcript or "")
        if dismiss:   # the team asked it or does not need it
            self.run_query("MATCH (l:LiveSession {uid: $uid}) SET l.dismissed = l.dismissed + "
                           "[d IN $ids WHERE NOT d IN l.dismissed]", uid=s["uid"], ids=list(dismiss)[:100])
        first, new, before, lines = new_part(transcript, s.get("lines_seen") or 0)
        question = tx.clean_text(question, 400)
        # the unfinished last line, read last time and not grown since: nothing new to read
        last = transcript.split("\n")[-1]
        partial = last if last.strip() else None
        if (not any(line.strip() for line in new) or (partial and new == [partial] and partial == s.get("partial"))) \
                and not question:
            return {"suggestions": [], "answer": None, "lines_seen": len(lines)}
        new_text = "\n".join(new)
        try:
            requirements = self.history(ctx, (question or "") + " " + new_text, s["project_key"])
            questions = self.open_questions(ctx, s["project_key"])
        except Exception as exc:   # no memory is no reason to stop helping
            log.warning("live memory unavailable: %s", type(exc).__name__)
            requirements, questions = [], []
        refs, memory = memory_block(requirements, questions,
                                    self._facts(ctx, (question or "") + " " + new_text, s["project_key"]))
        prompt = SESSION_PROMPT.format(project=s["project_key"], memory=memory, spoken=SPOKEN_NOTE,
                                       before=numbered(before, first - len(before)) or "none",
                                       new=numbered(new, first) or "none",
                                       question=question or "none", max=MAX_SUGGESTIONS)
        data = parse(self.llm(prompt))
        known = set(s.get("keys") or [])
        found = check(data.get("suggestions"), transcript, refs, known)
        answer = answer_text(data, transcript) if question else None
        given = (list(s.get("suggestions") or []) + [json.dumps(f, ensure_ascii=False) for f in found])[-MAX_KEPT:]
        self.run_query("MATCH (l:LiveSession {uid: $uid}) SET l.lines_seen = $seen, l.suggestions = $given, "
                       "l.keys = $keys, l.updated_at = $at, l.partial = $partial",
                       uid=s["uid"], seen=len(lines), given=given, keys=sorted(known)[-MAX_KEPT * 2:], at=_now(),
                       partial=partial)
        return {"suggestions": found, "answer": answer, "lines_seen": len(lines)}

    def wrap_up(self, ctx, session_id, transcript):
        """Before the meeting ends: read it all once and return what is still not covered (only points
        not given before), so the team can ask now."""
        s = self._load(ctx, session_id)
        if s["status"] != LIVE:
            raise MeetingError("this live session has ended", 409)
        transcript = tx.mask_sensitive(transcript or "")
        if not transcript.strip():
            return {"suggestions": []}
        lines = transcript.split("\n")
        try:
            questions = self.open_questions(ctx, s["project_key"])
            requirements = self.history(ctx, transcript[-4000:], s["project_key"])
        except Exception as exc:
            log.warning("live memory unavailable: %s", type(exc).__name__)
            requirements, questions = [], []
        refs, memory = memory_block(requirements, questions)
        given = [json.loads(x) for x in s.get("suggestions") or []]
        prompt = WRAP_UP_PROMPT.format(project=s["project_key"], memory=memory, max=MAX_WRAP_UP, spoken=SPOKEN_NOTE,
                                       given="\n".join(f"- {g['text']}" for g in given) or "none",
                                       transcript=numbered(lines, 1)[-WRAP_UP_CHARS:])
        known = set(s.get("keys") or [])
        found = check(parse(self.wrap_llm(prompt)).get("suggestions"), transcript, refs, known, limit=MAX_WRAP_UP)
        kept = (list(s.get("suggestions") or []) + [json.dumps(f, ensure_ascii=False) for f in found])[-MAX_KEPT:]
        self.run_query("MATCH (l:LiveSession {uid: $uid}) SET l.lines_seen = $seen, l.suggestions = $given, "
                       "l.keys = $keys, l.updated_at = $at",
                       uid=s["uid"], seen=len(lines), given=kept, keys=sorted(known)[-MAX_KEPT * 2:], at=_now())
        return {"suggestions": found}

    def end(self, ctx, session_id, transcript=None, meeting_date=None, created_by=None):
        """End the session: the questions for the next meeting, and the transcript (when sent) goes to the
        after-meeting pipeline as an online meeting source."""
        s = self._load(ctx, session_id)
        view = self.view(ctx, session_id)
        not_asked = [g for g in view["suggestions"] if g["kind"] in ("ask_client", "missing", "reminder")
                     and not g["done"]]
        try:
            still_open = self.open_questions(ctx, s["project_key"])
        except Exception as exc:
            log.warning("open questions unavailable: %s", type(exc).__name__)
            still_open = []
        source_id = s.get("source_id")
        if transcript and transcript.strip() and self.submit and not source_id:
            source_id = f"live-{s['session_id']}"[:200]
            self.submit(ctx, source_id, s["project_key"], "online", s.get("title"), meeting_date, transcript,
                        created_by=created_by)
        self.run_query("MATCH (l:LiveSession {uid: $uid}) SET l.status = $ended, l.ended_at = $at, "
                       "l.source_id = $source", uid=s["uid"], ended=ENDED, at=_now(), source=source_id)
        return {"session_id": s["session_id"], "status": ENDED, "source_id": source_id,
                "next_meeting": {"not_asked": [{"text": g["text"], "quote": g.get("quote"), "kind": g["kind"]}
                                               for g in not_asked],
                                 "open_questions": still_open}}

    def delete(self, ctx, session_id):
        s = self._load(ctx, session_id)
        self.run_query("MATCH (l:LiveSession {uid: $uid}) DETACH DELETE l", uid=s["uid"])
