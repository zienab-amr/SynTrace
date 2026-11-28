"""
meetings/chat_meeting.py
The chat as a way into live meeting help. In one chat the user says which project the meeting is about
(an existing one, or a new one created in SynTrace), then sends the transcript in parts while the meeting
goes on; each part gets the live help (meetings/session.py). "We're done" reads the whole meeting once
(wrap-up), ends the session and sends the transcript to review.

The agent never guesses the project: a project named in the message (its key or its name) is taken; with
one allowed project that one is taken; otherwise it asks one question, keeping the part it was sent until
the answer. One chat holds one meeting at a time.

Nothing here imports the graph or the web: the store (run_query), the live helper and the project names
are passed in.
"""
import hashlib
import re
from datetime import datetime, timezone

from syntrace_ai.meetings import text as tx
from syntrace_ai.meetings.errors import MeetingError

START = re.compile(r"\b(meeting|transcript|call with the client)\b|ميتنج|ميتينج|اجتماع|ترانسكريبت|"
                   r"الترانسكريبت|مع العميل", re.I)
NEW = re.compile(r"\bnew project\b|(project|بروجكت|بروجيكت|مشروع)\s*(جديد|جديدة)", re.I)
END = re.compile(r"\b(we('| a)re done|meeting (is )?(over|done|finished)|end (the )?meeting|finish(ed)? "
                 r"(the )?meeting)\b|خلصنا|خلص الميتنج|الميتنج خلص|خلصت الميتنج|انتهى الاجتماع|نقفل الميتنج", re.I)
QUESTION = re.compile(r"[?؟]")
MAX_CHOICES = 6
MAX_TRANSCRIPT = 400_000
LIVE, PENDING, ENDED = "live", "pending", "ended"

LABELS = {"ask_client": ("اسأل العميل", "Ask the client"), "missing": ("ناقص", "Missing"),
          "conflict": ("تعارض", "Conflict"), "reminder": ("تذكير", "Reminder"), "risk": ("خطر", "Risk"),
          "unverified": ("مش متسجّل", "Not on record")}


def _now():
    return datetime.now(timezone.utc).isoformat()


def chat_uid(tenant, employee, conversation):
    """One meeting per chat and per person: the backend's chat id alone is not trusted to be unique."""
    digest = hashlib.sha256(f"{employee}\n{conversation}".encode()).hexdigest()[:24]
    return f"{tenant}:chatmeeting:{digest}"


def arabic(text):
    return bool(re.search(r"[؀-ۿ]", text or ""))


def append(stored, part):
    """The transcript so far with the new part added once (the same part sent twice is not doubled)."""
    stored, part = (stored or "").rstrip("\n"), (part or "").strip("\n")
    if not part.strip() or part.strip() in stored:
        return stored
    return (stored + "\n" + part if stored else part)[-MAX_TRANSCRIPT:]


def named_projects(message, projects):
    """Projects ({key: name}) the message names by key (a whole word) or by name."""
    norm = tx.normalize(message)
    words = set(re.findall(r"(?<![A-Za-z0-9-])([A-Za-z][A-Za-z0-9]{1,15})(?![A-Za-z0-9]|-\d)", message or ""))
    found = []
    for key, name in projects.items():
        if key in {w.upper() for w in words if w.isupper()} or (name and len(name) > 2 and tx.normalize(name) in norm):
            found.append(key)
    return sorted(set(found))


def format_help(result, ar):
    """The live help as the chat reply: the answer to the team's question, then one line per suggestion."""
    lines = []
    if result.get("answer") and result["answer"].get("text"):
        lines.append(result["answer"]["text"])
    for g in result.get("suggestions") or []:
        label = LABELS.get(g["kind"], (g["kind"], g["kind"]))[0 if ar else 1]
        ref = g.get("ref") or {}
        where = f" ({ref.get('where')})" if ref.get("where") else ""
        lines.append(f"- {label}: {g['text']}{where}")
    if not lines:
        lines.append("مفيش حاجة جديدة محتاجة تنبيه في الجزء ده. ابعت الجزء اللي بعده." if ar
                     else "Nothing new to point out in this part. Send the next part.")
    return "\n".join(lines)


class ChatMeetings:
    """`live` is the live helper (LiveSessions), `projects(ctx)` -> {key: name} of the user's projects
    (Jira projects and the SynTrace projects the backend allows), `open_questions(ctx, project)` the
    questions earlier meetings left open."""

    def __init__(self, run_query, live, projects, open_questions):
        self.run_query, self.live, self.projects, self.open_questions = run_query, live, projects, open_questions

    def _state(self, uid):
        rows = self.run_query("MATCH (c:ChatMeeting {uid: $uid}) RETURN c {.*} AS c", uid=uid)
        return dict(rows[0]["c"]) if rows else None

    def _save(self, uid, ctx, **fields):
        self.run_query("MERGE (c:ChatMeeting {uid: $uid}) ON CREATE SET c.tenant_id = $tenant, c.created_at = $at "
                       "SET c += $fields, c.updated_at = $at", uid=uid, tenant=ctx.tenant_id, at=_now(),
                       fields=fields)

    def handle(self, ctx, employee, conversation, message, transcript=None, meeting_date=None):
        """-> None when the message is not about a meeting (the normal chat answers it), else
        {"answer": text, "status": "ok", "meeting": {...}}."""
        if not conversation:
            return None
        uid = chat_uid(ctx.tenant_id, employee, conversation)
        state = self._state(uid)
        active = state and state.get("status") in (LIVE, PENDING)
        transcript = (transcript or "").strip()
        if not transcript and not active and not START.search(message or ""):
            return None
        if active and not transcript and not END.search(message or "") and not START.search(message or "") \
                and state.get("status") == LIVE:
            return None   # a normal question in the middle of a meeting: the chat answers it
        # the message's language; a short English answer ("Delivery App") keeps the meeting's language
        ar = arabic(message) or arabic(transcript)
        if not ar and active and state.get("arabic") and len((message or "").split()) <= 3:
            ar = True
        projects = self.projects(ctx) or {}
        project = (state or {}).get("project_key") if active else None
        stored = (state or {}).get("transcript") if active else ""
        if transcript:
            stored = append(stored, tx.mask_sensitive(transcript))

        if not project:
            named = named_projects(message, projects)
            if len(named) == 1:
                project = named[0]
            elif len(projects) == 1 and not NEW.search(message or ""):
                project = next(iter(projects))
            else:
                self._save(uid, ctx, status=PENDING, transcript=stored, project_key=None, conversation_id=conversation,
                           arabic=ar)
                return self._ask_project(named or sorted(projects), projects, NEW.search(message or ""), ar)

        was_pending = bool(active and state.get("status") == PENDING)
        if active and state.get("status") == LIVE and state.get("session_id"):
            session_id, count = state["session_id"], state.get("count") or 1
        else:   # a new meeting in this chat: its own live session
            count = ((state or {}).get("count") or 0) + 1
            session_id = f"chat-{uid.rsplit(':', 1)[-1]}-{count}"
            self.live.start(ctx, session_id, project, title="Chat meeting", started_by=employee)
        self._save(uid, ctx, status=LIVE, transcript=stored, project_key=project, session_id=session_id,
                   conversation_id=conversation, count=count, arabic=ar)

        if END.search(message or ""):
            return self._finish(ctx, uid, session_id, project, stored, meeting_date, employee, ar)
        if stored and (transcript or was_pending):
            question = message if QUESTION.search(message or "") else None
            result = self.live.assist(ctx, session_id, stored, question=question)
            return {"status": "ok", "answer": format_help(result, ar),
                    "meeting": {"sessionId": session_id, "project": project, "suggestions": result["suggestions"]}}
        return self._welcome(ctx, project, projects, session_id, ar)

    def _ask_project(self, choices, projects, new, ar):
        shown = [f"{k} ({projects[k]})" if projects.get(k) and projects[k] != k else k for k in choices[:MAX_CHOICES]]
        if not shown:
            text = ("مش لاقي أي project مسموحلك. لو ده project جديد، اعمله في SynTrace الأول وبعدين قولي اسمه."
                    if ar else "I can't find a project you can use. If it is a new project, create it in SynTrace "
                               "first, then tell me its name.")
        elif new:
            text = (("الـ project الجديد ده أنهي واحد فيهم؟ " if ar else "Which of these is the new project? ")
                    + ", ".join(shown) + (". لو لسه مش متعمل، اعمله في SynTrace الأول." if ar
                                          else ". If it is not there yet, create it in SynTrace first."))
        else:
            text = ("الـ meeting ده على أنهي project؟ " if ar else "Which project is this meeting about? ") + \
                ", ".join(shown)
        return {"status": "ok", "answer": text, "meeting": {"needsProject": True, "choices": choices[:MAX_CHOICES]}}

    def _welcome(self, ctx, project, projects, session_id, ar):
        try:
            questions = self.open_questions(ctx, project) or []
        except Exception:
            questions = []
        name = projects.get(project) or project
        if ar:
            lines = [f"تمام، الـ meeting على {name}. ابعتلي الكلام أول بأول وأنا هقولك تسأل إيه وأنبّهك لو فيه "
                     f"حاجة متعارضة أو مش متسجّلة. ولما تخلص قول «خلصنا»."]
            if questions:
                lines.append("أسئلة لسه مفتوحة من meetings قبل كده:")
        else:
            lines = [f"OK, the meeting is about {name}. Send me the transcript as you go and I will suggest what "
                     f"to ask and flag anything that conflicts or is not on record. Say \"we're done\" at the end."]
            if questions:
                lines.append("Questions still open from earlier meetings:")
        lines += [f"- {q['text']} ({q.get('meeting') or 'meeting'}, {q.get('date')})" for q in questions[:5]]
        return {"status": "ok", "answer": "\n".join(lines),
                "meeting": {"sessionId": session_id, "project": project, "suggestions": []}}

    def _finish(self, ctx, uid, session_id, project, stored, meeting_date, employee, ar):
        try:
            wrap = self.live.wrap_up(ctx, session_id, stored)["suggestions"] if stored.strip() else []
        except MeetingError:
            wrap = []
        ended = self.live.end(ctx, session_id, stored or None, meeting_date, employee)
        self._save(uid, ctx, status=ENDED, ended_at=_now(), source_id=ended.get("source_id"))
        lines = []
        if wrap:
            lines.append("قبل ما تقفل، لسه ماتسألش عن:" if ar else "Before you close, still not covered:")
            lines += [f"- {g['text']}" for g in wrap]
        if ended.get("source_id"):
            lines.append("والـ meeting راح للمراجعة: هتلاقي الـ requirements والـ notes جاهزين تراجعهم."
                         if ar else "The meeting went to review: its requirements and notes are ready for you.")
        elif not wrap:
            lines.append("تمام، قفلت الـ meeting." if ar else "OK, the meeting is closed.")
        return {"status": "ok", "answer": "\n".join(lines),
                "meeting": {"sessionId": session_id, "project": project, "ended": True,
                            "sourceId": ended.get("source_id"), "suggestions": wrap}}
