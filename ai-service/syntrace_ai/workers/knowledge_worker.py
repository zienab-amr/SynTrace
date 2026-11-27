"""
knowledge_worker.py
The AI side of the backend's knowledge sources (meeting notes, requirements, documentation).
The backend owns upload, versions, review and publication; this worker only extracts and indexes.

  pending   GET  /api/internal/knowledge/pending?companyId=           for each authorized company
            -> text (or the PDF's text) -> mask numbers -> model items (meeting_notes.extract_items)
            -> each item's quote cut verbatim from the saved text -> POST .../extraction
               (or a failureCode) -> the backend shows them for review
  changes   GET  /api/internal/knowledge/changes?companyId=&after=     cursor per company, kept in Neo4j
            published -> GET .../published -> replace the source's approved evidence in the graph
            removed   -> delete the source's evidence

Graph (approved evidence only, with its provenance):
  (:KnowledgeSource {uid, tenant_id, syntrace_project_id, source_id, version, kind, title, meeting_at})
     -[:HAS_EVIDENCE]->(:KnowledgeEvidence {uid, evidence_id, kind, text, quote, quote_offset, embedding})
Search is scoped by the SynTrace project ids the backend allows for the asker; with none, knowledge
is not searched (deny by default).

Companies come from the backend's feed (GET /api/internal/knowledge/companies), KNOWLEDGE_COMPANY_IDS,
and the companies whose Jira data is in the graph. A backend without the feed (404/405) is fine.

  python knowledge_worker.py           runs until stopped
"""
import logging
import math
import os
import re
import signal
import time

import requests

log = logging.getLogger("syntrace.knowledge")

API_URL = os.getenv("KNOWLEDGE_API_URL", "").rstrip("/")
POLL_SECONDS = float(os.getenv("KNOWLEDGE_POLL_SECONDS", "15"))
HTTP_TIMEOUT = float(os.getenv("KNOWLEDGE_HTTP_TIMEOUT_SECONDS", "30"))
PENDING_TAKE = 5
CHANGES_TAKE = 20
MAX_ITEMS = 100          # the backend's limit per submission
MAX_TEXT = 256_000       # the backend's limit for source text
MAX_QUOTE = 4000
SEARCH_MIN_SCORE = float(os.getenv("KNOWLEDGE_SEARCH_MIN_SCORE", "0.35"))
EVIDENCE_KINDS = {"requirement": "Requirement", "decision": "Decision", "action_item": "ActionItem",
                  "open_question": "OpenQuestion", "blocker": "Blocker"}
SOURCE_TYPES = {"MeetingNotes": "online", "Requirements": "note", "Documentation": "note"}


class BackendError(Exception):
    pass


# ---------- 1. The backend's internal API ----------

class Backend:
    """X-Internal-Api-Key is the key the backend also uses to call /ask (AI_API_KEY)."""

    def __init__(self, base_url=None, api_key=None, session=None):
        self.base = (base_url or API_URL).rstrip("/")
        self.key = api_key or os.getenv("AI_API_KEY", "")
        self.http = session or requests.Session()
        if not self.base or not self.key:
            raise BackendError("KNOWLEDGE_API_URL and AI_API_KEY are required")

    def _call(self, method, path, company, ok=(200,), **kwargs):
        response = self.http.request(method, f"{self.base}/api/internal/knowledge{path}",
                                     params={"companyId": company, **kwargs.pop("params", {})},
                                     headers={"X-Internal-Api-Key": self.key}, timeout=HTTP_TIMEOUT, **kwargs)
        if response.status_code in ok:
            return response
        if response.status_code in (404, 409):
            return response            # superseded or gone: the caller decides
        raise BackendError(f"{method} {path.split('?')[0]} -> {response.status_code}")

    def pending(self, company, take=PENDING_TAKE):
        return self._call("GET", "/pending", company, params={"take": take}).json()

    def pdf(self, company, source_id, version):
        response = self._call("GET", f"/sources/{source_id}/versions/{version}/pdf", company)
        return response.content if response.status_code == 200 else None

    def submit(self, company, source_id, version, body):
        """-> the HTTP status: 204 accepted, 409 superseded, 404 gone."""
        return self._call("POST", f"/sources/{source_id}/versions/{version}/extraction", company,
                          ok=(200, 204), json=body).status_code

    def changes(self, company, after, take=CHANGES_TAKE):
        return self._call("GET", "/changes", company, params={"after": after, "take": take}).json()

    def identities(self, company):
        """Who linked which Jira and GitHub accounts, or None while the backend has no such endpoint."""
        response = self.http.request("GET", f"{self.base}/api/internal/identities", params={"companyId": company},
                                     headers={"X-Internal-Api-Key": self.key}, timeout=HTTP_TIMEOUT)
        if response.status_code in (404, 405):
            return None
        if response.status_code != 200:
            raise BackendError(f"GET /identities -> {response.status_code}")
        body = response.json()
        return body.get("items", body) if isinstance(body, dict) else body

    def companies(self):
        """Companies that have knowledge sources, or None while the backend has no such endpoint."""
        response = self.http.request("GET", f"{self.base}/api/internal/knowledge/companies",
                                     headers={"X-Internal-Api-Key": self.key}, timeout=HTTP_TIMEOUT)
        if response.status_code in (404, 405):
            return None
        if response.status_code != 200:
            raise BackendError(f"GET /companies -> {response.status_code}")
        body = response.json()
        items = body.get("items", []) if isinstance(body, dict) else body
        return [str(c).strip() for c in items if str(c or "").strip()][:10000]

    def published(self, company, project_id, source_id, version):
        response = self._call("GET", f"/sources/{source_id}/versions/{version}/published", company,
                              params={"projectId": project_id})
        return response.json() if response.status_code == 200 else None


# ---------- 2. Verbatim quotes ----------

_TASHKEEL = set("ًٌٍَُِّْٰـ")
_SAME = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ى": "ي", "ة": "ه", "ؤ": "و", "ئ": "ي"})
_PUNCT = set("\"'“”‘’«»`.,،؛;:!?؟()[]{}-–—_*")


def _folded(text):
    """(folded text, index of each folded character in the original). Folding is the evidence check's:
    no tashkeel, one alef, lower case, punctuation and runs of space as one space."""
    chars, where = [], []
    for i, c in enumerate(text):
        if c in _TASHKEEL:
            continue
        c = c.lower().translate(_SAME)
        if c in _PUNCT or c.isspace():
            if chars and chars[-1] != " ":
                chars.append(" ")
                where.append(i)
            continue
        chars.append(c)
        where.append(i)
    return "".join(chars), where


def verbatim_quote(evidence, text, folded=None):
    """The exact part of `text` that the model's evidence quotes, so the backend finds it with an exact
    match even when the model changed a hamza, a space or a mark. A quote in parts ("A ... B") becomes
    the text from A to B when they come in that order and close together. -> None when not found."""
    body, where = folded or _folded(text)
    parts = [_folded(p)[0].strip() for p in re.split(r"\.\.\.|…", evidence or "")]
    parts = [p for p in parts if len(p) >= 4]
    if not parts:
        return None
    spans, start_at = [], 0
    for part in parts:
        at = body.find(part, start_at)
        if at < 0:
            return None
        spans.append((at, at + len(part)))
        start_at = at + len(part)
    first, last = spans[0][0], spans[-1][1]
    start, end = where[first], where[last - 1] + 1
    quote = text[start:end].strip()
    if len(quote) > MAX_QUOTE:     # parts far apart: keep the first part alone
        quote = text[where[spans[0][0]]:where[spans[0][1] - 1] + 1].strip()
    return quote if quote and quote in text else None


# ---------- 3. Extraction ----------

def _text_of(job, backend, company):
    """The source text, and for a PDF the text to send back as extractedText. -> (text, extracted)."""
    if job.get("mediaType") == "application/pdf" or (job.get("fileName") or "").lower().endswith(".pdf"):
        data = backend.pdf(company, job["id"], job["version"])
        if not data:
            return None, None
        import base64
        from syntrace_ai.meetings import meeting_notes as mn
        # raises MeetingError for a scanned PDF; page breaks let the index name each quote's page
        text = mn.pdf_text(base64.b64encode(data).decode(), page_breaks=True)
        return text, text
    return job.get("text") or "", None


def extraction_body(job, text, extracted, llm=None):
    """The body for POST .../extraction: checked items with verbatim quotes, or a failure code."""
    from syntrace_ai.meetings import meeting_notes as mn
    if not text or not text.strip() or len(text) > MAX_TEXT:
        return {"failureCode": "Unreadable"}
    masked = mn.mask_sensitive(text)
    kind = SOURCE_TYPES.get(str(job.get("kind")), "note")
    items, _rejected = mn.extract_items(masked, job.get("projectId") or "the client's project", kind,
                                        job.get("title"), "unknown date", llm=llm)
    folded = _folded(text)
    out, seen = [], set()
    for item in items:
        if mn.MASK in item["evidence"] or mn.EMAIL_MASK in item["evidence"]:
            continue
        quote = verbatim_quote(item["evidence"], text, folded)
        key = (item["type"], quote, item["text"])
        if not quote or key in seen:
            continue
        seen.add(key)
        out.append({"kind": EVIDENCE_KINDS[item["type"]], "text": item["text"][:2000], "quote": quote})
        if len(out) == MAX_ITEMS:
            break
    body = {"items": out}
    if extracted is not None:
        body["extractedText"] = extracted[:MAX_TEXT]
    return body


def process_pending(backend, company, llm=None):
    """Extract every pending version of one company. -> how many were submitted."""
    from syntrace_ai.meetings import meeting_notes as mn
    done = 0
    for job in backend.pending(company):
        try:
            text, extracted = _text_of(job, backend, company)
            if text is None:
                continue                      # the version changed or is gone
            body = extraction_body(job, text, extracted, llm=llm)
        except mn.MeetingError as exc:
            if isinstance(exc, mn.ExtractionUnavailable) and "rate limit" in str(exc):
                log.info("knowledge extraction waits for the rate limit")
                return done                   # stays pending; the next poll tries again
            body = {"failureCode": "Unreadable" if exc.status in (413, 422) else "ExtractionUnavailable"}
        status = backend.submit(company, job["id"], job["version"], body)
        log.info("knowledge extraction submitted status=%s items=%d failure=%s", status,
                 len(body.get("items") or []), body.get("failureCode"))
        done += status in (200, 204)
    return done


# ---------- 4. Approved evidence in the graph ----------

def _cursor(tenant):
    from syntrace_ai.graph.query_engine import run_query
    rows = run_query("MATCH (c:KnowledgeCursor {tenant_id: $t}) RETURN c.after AS after", t=tenant)
    return rows[0]["after"] if rows else 0


def _save_cursor(tenant, after):
    from syntrace_ai.graph.query_engine import run_query
    run_query("MERGE (c:KnowledgeCursor {tenant_id: $t}) SET c.after = $after", t=tenant, after=after)


def source_uid(tenant, source_id):
    return f"{tenant}:knowledge:{source_id}"


def remove_source(tenant, source_id):
    from syntrace_ai.graph.query_engine import run_query
    run_query("MATCH (s:KnowledgeSource {uid: $uid, tenant_id: $t}) OPTIONAL MATCH (s)-[:HAS_EVIDENCE]->(e) "
              "DETACH DELETE e, s", uid=source_uid(tenant, source_id), t=tenant)


def index_published(tenant, project_id, view, embed=None):
    """Replace a source's evidence with the approved evidence of this published version."""
    from syntrace_ai.graph.embeddings import embed_texts
    from syntrace_ai.graph.query_engine import get_driver
    source = view["source"]
    evidence = [e for e in view.get("evidence") or [] if str(e.get("decision")) in ("Approved", "1")]
    vectors = (embed or embed_texts)([f"{e['text']}\n{e['quote']}" for e in evidence]) if evidence else []
    uid = source_uid(tenant, source["id"])
    props = {"uid": uid, "tenant_id": tenant, "syntrace_project_id": project_id, "source_id": source["id"],
             "client_id": source.get("clientId"), "version": source.get("publishedVersion") or source.get("version"),
             "kind": str(source.get("kind")), "title": source.get("title"), "meeting_at": view.get("meetingAt"),
             "meeting_mode": view.get("meetingMode") and str(view.get("meetingMode")), "indexed_at": time.time()}
    from syntrace_ai.meetings import meeting_notes as mn
    source_text = view.get("sourceText") or ""
    rows = [{"uid": f"{uid}:evidence:{e['id']}", "evidence_id": e["id"], "kind": str(e["kind"]), "text": e["text"],
             "quote": e["quote"], "quote_offset": e.get("quoteOffset"),
             "page": mn.page_of(source_text, e.get("quoteOffset")), "embedding": list(v),
             "tenant_id": tenant, "syntrace_project_id": project_id, "version": props["version"]}
            for e, v in zip(evidence, vectors)]

    def work(tx):
        tx.run("MATCH (s:KnowledgeSource {uid: $uid}) OPTIONAL MATCH (s)-[:HAS_EVIDENCE]->(e) DETACH DELETE e, s", uid=uid)
        if not rows:
            return
        tx.run("CREATE (s:KnowledgeSource) SET s = $props", props=props)
        tx.run("MATCH (s:KnowledgeSource {uid: $uid}) UNWIND $rows AS r CREATE (e:KnowledgeEvidence) SET e = r "
               "CREATE (s)-[:HAS_EVIDENCE]->(e)", uid=uid, rows=rows)
    with get_driver().session() as session:
        session.execute_write(work)
    return len(rows)


def apply_changes(backend, tenant, embed=None):
    """Apply publication changes in order; the cursor moves after each one, so a stop replays safely."""
    after = _cursor(tenant)
    applied = 0
    while True:
        changes = backend.changes(tenant, after)
        if not changes:
            return applied
        for change in changes:
            if change.get("removed"):
                remove_source(tenant, change["sourceId"])
            else:
                view = backend.published(tenant, change["projectId"], change["sourceId"], change["version"])
                if view is not None:          # 404: a later change superseded it
                    index_published(tenant, change["projectId"], view, embed=embed)
            after = change["cursor"]
            _save_cursor(tenant, after)
            applied += 1
        if len(changes) < CHANGES_TAKE:
            return applied


# ---------- 5. Search for the assistant ----------

def search_knowledge(question, ctx, k=5, min_score=SEARCH_MIN_SCORE, embed=None):
    """Approved evidence closest to the question, only in the asker's allowed SynTrace projects."""
    from syntrace_ai.graph.embeddings import embed_texts
    from syntrace_ai.graph.query_engine import run_query
    projects = list(getattr(ctx, "syntrace_projects", ()) or ())
    if not projects:
        return []
    rows = run_query(
        """
        MATCH (s:KnowledgeSource {tenant_id: $t})-[:HAS_EVIDENCE]->(e:KnowledgeEvidence)
        WHERE s.syntrace_project_id IN $projects AND e.embedding IS NOT NULL
        RETURN s.title AS title, s.kind AS source_kind, s.meeting_at AS meeting_at, s.version AS version,
               s.indexed_at AS indexed_at, s.source_id AS source_id, e.evidence_id AS evidence_id,
               e.kind AS kind, e.text AS text, e.quote AS quote, e.page AS page, e.embedding AS emb
        """, t=ctx.tenant_id, projects=projects)
    if not rows:
        return []
    query = (embed or embed_texts)([question])[0]
    qn = math.sqrt(sum(x * x for x in query)) or 1.0
    scored = []
    for r in rows:
        v = r["emb"]
        score = sum(a * b for a, b in zip(query, v)) / (qn * (math.sqrt(sum(x * x for x in v)) or 1.0))
        if score >= min_score:
            scored.append((score, {k2: r[k2] for k2 in r.keys() if k2 != "emb"}))
    scored.sort(key=lambda p: p[0], reverse=True)
    # The closest k, then newest first: when two sources disagree, the newer one is the client's current word.
    top = [dict(hit, score=round(s, 3), date=_source_date(hit)) for s, hit in scored[:k]]
    return sorted(top, key=lambda h: h["date"] or "", reverse=True)


def _source_date(hit):
    """A meeting's date, else the day the source was published (approved) to the assistant."""
    if hit.get("meeting_at"):
        return str(hit["meeting_at"])[:10]
    if hit.get("indexed_at"):
        return time.strftime("%Y-%m-%d", time.gmtime(float(hit["indexed_at"])))
    return None


SOURCE_KINDS = {"MeetingNotes": "meeting", "Requirements": "requirements note", "Documentation": "document"}


def knowledge_context(hits):
    lines = ["Approved knowledge (client meetings, requirements, documents), newest first. If two disagree, "
             "the newest is the current decision; give the older one as background with its date:"]
    for h in hits:
        kind = SOURCE_KINDS.get(str(h.get("source_kind")), str(h.get("source_kind") or "source"))
        when = (f", {h['date']}" if h.get("meeting_at") else f", approved {h['date']}") if h.get("date") else ""
        page = f", page {h['page']}" if h.get("page") else ""
        lines.append(f"- {h['kind']}: {h['text']} | quote: \"{h['quote'][:300]}\" | source: \"{h['title']}\""
                     f" ({kind}{when}{page}, version {h['version']})")
    return "\n".join(lines)


# ---------- 6. The loop ----------

def companies(backend=None):
    """Companies to poll: the backend's feed, KNOWLEDGE_COMPANY_IDS, and those whose Jira data is in the graph."""
    from syntrace_ai.graph.query_engine import run_query
    listed = {c.strip() for c in os.getenv("KNOWLEDGE_COMPANY_IDS", "").split(",") if c.strip()}
    if backend is not None:
        try:
            listed |= set(backend.companies() or [])
        except Exception as exc:   # the feed is optional: the other sources still count
            log.warning("backend company feed unavailable: %s", type(exc).__name__)
    if os.getenv("KNOWLEDGE_TENANTS_FROM_GRAPH", "1") == "1":
        try:
            listed |= {r["t"] for r in run_query("MATCH (p:Project) WHERE p.tenant_id IS NOT NULL "
                                                 "RETURN DISTINCT p.tenant_id AS t") if r["t"]}
        except Exception as exc:
            log.warning("graph companies unavailable: %s", type(exc).__name__)
    return sorted(listed)


def sync_identities(backend, company, session_factory=None):
    """GitHub-to-Jira links for one company. -> how many, or None when the backend does not offer them."""
    from syntrace_ai.github import github_graph
    rows = backend.identities(company)
    if rows is None or not isinstance(rows, list):
        return None
    if session_factory is None:
        from syntrace_ai.graph.query_engine import get_driver
        session_factory = lambda: get_driver().session()
    with session_factory() as session:
        return session.execute_write(lambda tx: github_graph.link_identities(tx, company, rows))


def run_once(backend, llm=None, embed=None):
    for company in companies(backend):
        try:
            process_pending(backend, company, llm=llm)
            apply_changes(backend, company, embed=embed)
            sync_identities(backend, company)
        except Exception as exc:   # one company's failure never stops the others
            log.warning("knowledge sync failed for a company: %s", type(exc).__name__)


def main():
    from dotenv import load_dotenv
    load_dotenv()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    backend = Backend()
    stopping = []
    signal.signal(signal.SIGTERM, lambda *a: stopping.append(1))
    log.info("knowledge worker started")
    while not stopping:
        run_once(backend)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
