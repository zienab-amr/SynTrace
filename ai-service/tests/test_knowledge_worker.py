"""Offline tests for knowledge_worker.py: a fake backend with the same API, a fake model and a fake graph.
  python -m unittest test_knowledge_worker -v
"""
import json
import unittest
from unittest import mock

from syntrace_ai.workers import knowledge_worker as kw
from syntrace_ai.meetings import meeting_notes as mn
from syntrace_ai.graph.query_engine import AccessContext

TEXT = ("محضر اجتماع مع العميل.\n"
        "العميل طلب إن المستخدم يقدر يغيّر كلمة السر من صفحة الإعدادات.\n"
        "اتفقنا نستخدم PostgreSQL بدل MongoDB.\n"
        "Rodaina will send the new login screens by Thursday.\n"
        "رقم التليفون 01012345678 للتواصل.")


def reply(*items):
    return lambda prompt: json.dumps({"items": list(items)}, ensure_ascii=False)


class FakeResponse:
    def __init__(self, status, body=None, content=b""):
        self.status_code, self._body, self.content = status, body, content

    def json(self):
        return self._body


class FakeBackend:
    """Same shapes as /api/internal/knowledge; records what the worker submits."""
    def __init__(self, pending=(), changes=(), views=None, submit_status=204):
        self._pending, self._changes = list(pending), list(changes)
        self.views, self.submit_status, self.submitted = views or {}, submit_status, []

    def pending(self, company, take=kw.PENDING_TAKE):
        return [j for j in self._pending if j.get("company", company) == company][:take]

    def pdf(self, company, source_id, version):
        return None

    def submit(self, company, source_id, version, body):
        # the backend's own check: every quote must occur in the saved text exactly
        job = next(j for j in self._pending if j["id"] == source_id)
        source = body.get("extractedText") or job.get("text") or ""
        if any(i["quote"] not in source for i in body.get("items", [])):
            self.submitted.append((source_id, version, body, 400))
            return 400
        self.submitted.append((source_id, version, body, self.submit_status))
        return self.submit_status

    def changes(self, company, after, take=kw.CHANGES_TAKE):
        return [c for c in self._changes if c["cursor"] > after][:take]

    def published(self, company, project_id, source_id, version):
        return self.views.get((source_id, version))


class VerbatimQuoteTests(unittest.TestCase):
    def test_exact_quote_is_kept(self):
        self.assertEqual(kw.verbatim_quote("اتفقنا نستخدم PostgreSQL بدل MongoDB", TEXT),
                         "اتفقنا نستخدم PostgreSQL بدل MongoDB")

    def test_hamza_marks_and_spaces_map_back_to_the_saved_text(self):
        quote = kw.verbatim_quote("العميل طلب ان المستخدم  يقدر يغير كلمه السر", TEXT)
        self.assertIn(quote, TEXT)
        self.assertTrue(quote.startswith("العميل طلب إن"))
        self.assertIn("يغيّر", quote)

    def test_quote_in_parts_becomes_the_span(self):
        quote = kw.verbatim_quote("Rodaina will send ... by Thursday", TEXT)
        self.assertEqual(quote, "Rodaina will send the new login screens by Thursday")

    def test_missing_or_out_of_order_returns_none(self):
        self.assertIsNone(kw.verbatim_quote("the client wants dark mode", TEXT))
        self.assertIsNone(kw.verbatim_quote("by Thursday ... Rodaina will send", TEXT))
        self.assertIsNone(kw.verbatim_quote("", TEXT))


class ExtractionTests(unittest.TestCase):
    JOB = {"id": "s1", "version": 2, "kind": "MeetingNotes", "projectId": "p1", "title": "Kickoff", "text": TEXT}

    def test_items_have_kinds_and_verbatim_quotes(self):
        llm = reply({"type": "requirement", "text": "Users change their password in settings",
                     "evidence": "العميل طلب ان المستخدم يقدر يغير كلمة السر من صفحة الاعدادات"},
                    {"type": "decision", "text": "Use PostgreSQL", "evidence": "اتفقنا نستخدم PostgreSQL بدل MongoDB"},
                    {"type": "action_item", "text": "Send login screens", "evidence": "Rodaina will send the new login screens"})
        body = kw.extraction_body(self.JOB, TEXT, None, llm=llm)
        self.assertEqual([i["kind"] for i in body["items"]], ["Requirement", "Decision", "ActionItem"])
        for item in body["items"]:
            self.assertIn(item["quote"], TEXT)
        self.assertNotIn("extractedText", body)

    def test_masked_phone_numbers_never_leave(self):
        llm = reply({"type": "action_item", "text": "Call the client", "evidence": "رقم التليفون [NUMBER] للتواصل"})
        body = kw.extraction_body(self.JOB, TEXT, None, llm=llm)
        self.assertEqual(body["items"], [])
        self.assertNotIn("01012345678", json.dumps(body, ensure_ascii=False))

    def test_the_model_sees_masked_text_only(self):
        prompts = []
        kw.extraction_body(self.JOB, TEXT, None, llm=lambda p: prompts.append(p) or '{"items": []}')
        self.assertTrue(prompts)
        self.assertNotIn("01012345678", prompts[0])

    def test_empty_or_too_long_text_is_unreadable(self):
        self.assertEqual(kw.extraction_body(self.JOB, "  ", None, llm=reply()), {"failureCode": "Unreadable"})
        self.assertEqual(kw.extraction_body(self.JOB, "x" * (kw.MAX_TEXT + 1), None, llm=reply()),
                         {"failureCode": "Unreadable"})

    def test_pdf_text_is_sent_back(self):
        body = kw.extraction_body(self.JOB, TEXT, TEXT, llm=reply())
        self.assertEqual(body["extractedText"], TEXT)

    def test_at_most_100_items(self):
        lines = "\n".join(f"Requirement number {chr(65 + i // 26)}{chr(65 + i % 26)} must be supported" for i in range(130))
        items = [{"type": "requirement", "text": f"req {i}",
                  "evidence": f"Requirement number {chr(65 + i // 26)}{chr(65 + i % 26)} must be supported"}
                 for i in range(130)]
        with mock.patch.object(mn, "MAX_ITEMS_PER_PART", 200), mock.patch.object(mn, "EXTRACT_CHARS", 100000):
            body = kw.extraction_body(dict(self.JOB, text=lines), lines, None, llm=reply(*items))
        self.assertEqual(len(body["items"]), kw.MAX_ITEMS)


class PendingTests(unittest.TestCase):
    def job(self, **kw_):
        return dict({"id": "s1", "version": 1, "kind": "Requirements", "projectId": "p1", "title": "SRS", "text": TEXT}, **kw_)

    def test_submits_and_backend_accepts(self):
        backend = FakeBackend(pending=[self.job()])
        llm = reply({"type": "decision", "text": "Use PostgreSQL", "evidence": "اتفقنا نستخدم PostgreSQL بدل MongoDB"})
        self.assertEqual(kw.process_pending(backend, "c1", llm=llm), 1)
        self.assertEqual(backend.submitted[0][3], 204)

    def test_bad_json_twice_reports_extraction_unavailable(self):
        backend = FakeBackend(pending=[self.job()])
        kw.process_pending(backend, "c1", llm=lambda p: "sorry")
        self.assertEqual(backend.submitted[0][2], {"failureCode": "ExtractionUnavailable"})

    def test_rate_limit_leaves_the_job_pending(self):
        backend = FakeBackend(pending=[self.job()])

        def limited(prompt):
            raise mn.ExtractionUnavailable("meeting extraction is rate limited; try again later")
        self.assertEqual(kw.process_pending(backend, "c1", llm=limited), 0)
        self.assertEqual(backend.submitted, [])

    def test_superseded_version_is_not_counted(self):
        backend = FakeBackend(pending=[self.job()], submit_status=409)
        self.assertEqual(kw.process_pending(backend, "c1", llm=reply()), 0)

    def test_pdf_gone_is_skipped(self):
        backend = FakeBackend(pending=[self.job(mediaType="application/pdf", text=None)])
        self.assertEqual(kw.process_pending(backend, "c1", llm=reply()), 0)
        self.assertEqual(backend.submitted, [])


class ChangesTests(unittest.TestCase):
    def setUp(self):
        self.cursor = {}
        self.indexed, self.removed = [], []
        patches = [
            mock.patch.object(kw, "_cursor", lambda t: self.cursor.get(t, 0)),
            mock.patch.object(kw, "_save_cursor", lambda t, a: self.cursor.__setitem__(t, a)),
            mock.patch.object(kw, "index_published", lambda t, p, v, embed=None: self.indexed.append((t, p, v["source"]["id"]))),
            mock.patch.object(kw, "remove_source", lambda t, s: self.removed.append((t, s))),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def test_applies_in_order_and_moves_the_cursor(self):
        view = {"source": {"id": "s1"}, "evidence": []}
        backend = FakeBackend(changes=[
            {"cursor": 1, "sourceId": "s1", "projectId": "p1", "version": 1},
            {"cursor": 2, "sourceId": "s9", "projectId": "p1", "version": 3},   # superseded: 404
            {"cursor": 3, "sourceId": "s2", "projectId": "p1", "version": 1, "removed": True}],
            views={("s1", 1): view})
        self.assertEqual(kw.apply_changes(backend, "c1"), 3)
        self.assertEqual(self.indexed, [("c1", "p1", "s1")])
        self.assertEqual(self.removed, [("c1", "s2")])
        self.assertEqual(self.cursor["c1"], 3)
        self.assertEqual(kw.apply_changes(backend, "c1"), 0)    # replay after a restart does nothing

    def test_pages_through_many_changes(self):
        changes = [{"cursor": i, "sourceId": f"s{i}", "projectId": "p1", "version": 1, "removed": True}
                   for i in range(1, 46)]
        self.assertEqual(kw.apply_changes(FakeBackend(changes=changes), "c1"), 45)
        self.assertEqual(self.cursor["c1"], 45)


class IndexTests(unittest.TestCase):
    def test_only_approved_evidence_is_indexed(self):
        runs = []

        class Tx:
            def run(self, query, **params):
                runs.append((query, params))

        class Session:
            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

            def execute_write(self, work):
                work(Tx())

        driver = mock.Mock()
        driver.session.return_value = Session()
        view = {"source": {"id": "s1", "kind": "MeetingNotes", "title": "Kickoff", "publishedVersion": 2},
                "meetingAt": "2026-11-20T10:00:00Z",
                "evidence": [{"id": "e1", "kind": "Decision", "text": "Use PostgreSQL", "quote": "q1", "decision": "Approved"},
                             {"id": "e2", "kind": "Requirement", "text": "Dark mode", "quote": "q2", "decision": "Rejected"},
                             {"id": "e3", "kind": "ActionItem", "text": "Screens", "quote": "q3", "decision": "Pending"}]}
        with mock.patch("syntrace_ai.graph.query_engine.get_driver", return_value=driver):
            n = kw.index_published("c1", "p1", view, embed=lambda texts: [[1.0, 0.0]] * len(texts))
        self.assertEqual(n, 1)
        rows = runs[-1][1]["rows"]
        self.assertEqual([r["evidence_id"] for r in rows], ["e1"])
        self.assertEqual(rows[0]["syntrace_project_id"], "p1")
        self.assertEqual(rows[0]["tenant_id"], "c1")

    def test_a_version_with_nothing_approved_clears_the_source(self):
        runs = []
        tx = mock.Mock()
        tx.run.side_effect = lambda q, **p: runs.append(q)
        session = mock.MagicMock()
        session.__enter__.return_value = session
        session.execute_write.side_effect = lambda work: work(tx)
        driver = mock.Mock()
        driver.session.return_value = session
        view = {"source": {"id": "s1"}, "evidence": [{"id": "e2", "kind": "Requirement", "text": "x", "quote": "q",
                                                       "decision": "Rejected"}]}
        with mock.patch("syntrace_ai.graph.query_engine.get_driver", return_value=driver):
            self.assertEqual(kw.index_published("c1", "p1", view, embed=lambda t: self.fail("embedded")), 0)
        self.assertEqual(len(runs), 1)
        self.assertIn("DETACH DELETE", runs[0])


class SearchTests(unittest.TestCase):
    ROWS = [{"title": "Kickoff", "source_kind": "MeetingNotes", "meeting_at": "2026-11-20", "version": 2,
             "source_id": "s1", "evidence_id": "e1", "kind": "Decision", "text": "Use PostgreSQL",
             "quote": "اتفقنا نستخدم PostgreSQL بدل MongoDB", "emb": [1.0, 0.0]},
            {"title": "SRS", "source_kind": "Requirements", "meeting_at": None, "version": 1,
             "source_id": "s2", "evidence_id": "e2", "kind": "Requirement", "text": "Unrelated",
             "quote": "x", "emb": [0.0, 1.0]}]

    def run_search(self, ctx):
        calls = []

        def fake_run(query, **params):
            calls.append(params)
            return self.ROWS
        with mock.patch("syntrace_ai.graph.query_engine.run_query", fake_run):
            hits = kw.search_knowledge("which database", ctx, embed=lambda t: [[1.0, 0.1]])
        return hits, calls

    def test_no_allowed_projects_means_no_knowledge(self):
        hits, calls = self.run_search(AccessContext("c1", ("SYNT",)))
        self.assertEqual(hits, [])
        self.assertEqual(calls, [])

    def test_scoped_to_tenant_and_projects_and_ranked(self):
        hits, calls = self.run_search(AccessContext("c1", ("SYNT",), None, ("p1",)))
        self.assertEqual(calls[0]["t"], "c1")
        self.assertEqual(calls[0]["projects"], ["p1"])
        self.assertEqual([h["evidence_id"] for h in hits], ["e1"])
        self.assertNotIn("emb", hits[0])
        context = kw.knowledge_context(hits)
        self.assertIn("Kickoff", context)
        self.assertIn("PostgreSQL", context)


class AgentToolTests(unittest.TestCase):
    def test_search_meetings_adds_knowledge_titles(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk.__new__(graph_agent.Walk)
        walk.ctx = AccessContext("c1", ("SYNT",), None, ("p1",))
        walk.meetings = set()
        hit = dict(SearchTests.ROWS[0], score=0.9)
        hit.pop("emb")
        with mock.patch("syntrace_ai.meetings.meeting_notes.search_meetings", return_value=[]), \
                mock.patch("syntrace_ai.workers.knowledge_worker.search_knowledge", return_value=[hit]):
            out = walk.search_meetings({"query": "which database"})
        self.assertIn("PostgreSQL", out)
        self.assertIn("Kickoff", walk.meetings)

    def test_both_searches_failing_says_unavailable(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk.__new__(graph_agent.Walk)
        walk.ctx = AccessContext("c1", ("SYNT",), None, ("p1",))
        walk.meetings = set()
        with mock.patch("syntrace_ai.meetings.meeting_notes.search_meetings", side_effect=RuntimeError), \
                mock.patch("syntrace_ai.workers.knowledge_worker.search_knowledge", side_effect=RuntimeError):
            self.assertEqual(walk.search_meetings({"query": "x"}), "Meeting search is unavailable.")


class AskRequestTests(unittest.TestCase):
    def test_field_and_cache_key(self):
        from syntrace_ai.api import ai_service
        req = ai_service.AskRequest(question="q", companyId="c1", employeeId="e1", allowedProjects=["SYNT"],
                                    allowedSynTraceProjectIds=["p2", " p1 ", ""])
        self.assertEqual(req.allowed_syntrace_project_ids, ["p2", " p1 ", ""])
        self.assertEqual(ai_service.AskRequest(question="q", companyId="c1", employeeId="e1").allowed_syntrace_project_ids, [])


if __name__ == "__main__":
    unittest.main()


class CompanyFeedTests(unittest.TestCase):
    """The backend's company feed adds companies; without it the worker still uses env and graph."""

    def _http(self, status, body=None):
        http = mock.Mock()
        http.request.return_value = FakeResponse(status, body)
        return http

    def test_feed_items(self):
        backend = kw.Backend("http://b", "k", session=self._http(200, {"items": ["c1", " c2 ", ""]}))
        self.assertEqual(backend.companies(), ["c1", "c2"])
        url = backend.http.request.call_args[0][1]
        self.assertTrue(url.endswith("/api/internal/knowledge/companies"))

    def test_feed_missing_is_none(self):
        self.assertIsNone(kw.Backend("http://b", "k", session=self._http(404)).companies())

    def test_feed_error_raises(self):
        with self.assertRaises(kw.BackendError):
            kw.Backend("http://b", "k", session=self._http(500)).companies()

    def test_companies_merge_feed_env_and_graph(self):
        backend = mock.Mock()
        backend.companies.return_value = ["fromfeed"]
        with mock.patch.dict("os.environ", {"KNOWLEDGE_COMPANY_IDS": "fromenv"}), \
                mock.patch("syntrace_ai.graph.query_engine.run_query", return_value=[{"t": "fromgraph"}]):
            self.assertEqual(kw.companies(backend), ["fromenv", "fromfeed", "fromgraph"])

    def test_broken_feed_keeps_other_sources(self):
        backend = mock.Mock()
        backend.companies.side_effect = kw.BackendError("GET /companies -> 500")
        with mock.patch.dict("os.environ", {"KNOWLEDGE_COMPANY_IDS": "fromenv",
                                            "KNOWLEDGE_TENANTS_FROM_GRAPH": "0"}):
            self.assertEqual(kw.companies(backend), ["fromenv"])

    def test_run_once_polls_feed_companies(self):
        backend = mock.Mock()
        backend.companies.return_value = ["c9"]
        with mock.patch.dict("os.environ", {"KNOWLEDGE_COMPANY_IDS": "", "KNOWLEDGE_TENANTS_FROM_GRAPH": "0"}), \
                mock.patch.object(kw, "process_pending") as pending, \
                mock.patch.object(kw, "apply_changes"), mock.patch.object(kw, "sync_identities"):
            kw.run_once(backend)
        self.assertEqual(pending.call_args[0][1], "c9")


def _two_page_pdf(first, second, blank_between=False):
    """A real text PDF, or None when reportlab (a test-only tool) is missing."""
    try:
        from reportlab.pdfgen import canvas
    except ImportError:
        return None
    import io
    out = io.BytesIO()
    c = canvas.Canvas(out)
    for page in [first] + ([""] if blank_between else []) + [second]:
        if page:
            c.drawString(72, 720, page)
        c.showPage()
    c.save()
    return out.getvalue()


class PdfPageTests(unittest.TestCase):
    """SYNT-565: a quote from a PDF names its page."""

    def test_page_breaks_and_page_of(self):
        import base64
        data = _two_page_pdf("The client wants a login page with Google.", "Payments go live in March.",
                             blank_between=True)
        if data is None:
            self.skipTest("reportlab is not installed")
        text = mn.pdf_text(base64.b64encode(data).decode(), page_breaks=True)
        self.assertEqual(text.count(mn.PAGE_BREAK), 2)              # 3 pages, the middle one blank
        self.assertEqual(mn.page_of(text, text.index("login")), 1)
        self.assertEqual(mn.page_of(text, text.index("Payments")), 3)
        plain = mn.pdf_text(base64.b64encode(data).decode())
        self.assertNotIn(mn.PAGE_BREAK, plain)                        # the meeting pipeline is unchanged

    def test_page_of_without_breaks_or_offset(self):
        self.assertIsNone(mn.page_of("a note, not a PDF", 3))
        self.assertIsNone(mn.page_of("a\fb", None))
        self.assertIsNone(mn.page_of("a\fb", 99))

    def test_quote_across_a_page_break_is_still_verbatim(self):
        text = "first page ends here with the requirement\n\f\nthat continues on page two."
        quote = kw.verbatim_quote("ends here with the requirement that continues", text)
        self.assertIn(quote, text)
        self.assertEqual(mn.page_of(text, text.index(quote)), 1)

    def test_scanned_pdf_with_breaks_is_still_refused(self):
        import base64
        import io
        from pypdf import PdfWriter
        writer, out = PdfWriter(), io.BytesIO()
        writer.add_blank_page(612, 792)
        writer.add_blank_page(612, 792)
        writer.write(out)
        with self.assertRaises(mn.MeetingError):
            mn.pdf_text(base64.b64encode(out.getvalue()).decode(), page_breaks=True)

    def test_index_stores_the_page(self):
        runs = []
        tx = mock.Mock()
        tx.run.side_effect = lambda q, **p: runs.append(p)
        session = mock.MagicMock()
        session.__enter__.return_value = session
        session.execute_write.side_effect = lambda work: work(tx)
        driver = mock.Mock()
        driver.session.return_value = session
        text = "Scope.\n\f\nThe client wants dark mode."
        view = {"source": {"id": "s1", "kind": "Requirements", "title": "SRS.pdf", "publishedVersion": 1},
                "sourceText": text, "fileName": "SRS.pdf",
                "evidence": [{"id": "e1", "kind": "Requirement", "text": "Dark mode", "decision": "Approved",
                              "quote": "The client wants dark mode.", "quoteOffset": text.index("The client")}]}
        with mock.patch("syntrace_ai.graph.query_engine.get_driver", return_value=driver):
            kw.index_published("c1", "p1", view, embed=lambda t: [[1.0]] * len(t))
        self.assertEqual(runs[-1]["rows"][0]["page"], 2)

    def test_answer_context_names_the_page(self):
        hit = {"kind": "Requirement", "text": "Dark mode", "quote": "The client wants dark mode.",
               "title": "SRS.pdf", "source_kind": "Requirements", "meeting_at": None, "date": "2026-11-21",
               "page": 2, "version": 1}
        line = kw.knowledge_context([hit])
        self.assertIn("page 2", line)
        self.assertIn("(requirements note, approved 2026-11-21, page 2, version 1)", line)


class NewestSourceTests(unittest.TestCase):
    """SYNT-569: sources name their type, title and date, and conflicting ones come newest first."""

    ROWS = [{"title": "Kickoff", "source_kind": "MeetingNotes", "meeting_at": "2026-10-01T10:00:00Z", "version": 1,
             "indexed_at": None, "source_id": "s1", "evidence_id": "e1", "kind": "Decision",
             "text": "Use MongoDB", "quote": "we will use MongoDB", "page": None, "emb": [1.0, 0.0]},
            {"title": "Follow-up", "source_kind": "MeetingNotes", "meeting_at": "2026-11-15T10:00:00Z", "version": 1,
             "indexed_at": None, "source_id": "s2", "evidence_id": "e2", "kind": "Decision",
             "text": "Use PostgreSQL instead of MongoDB", "quote": "PostgreSQL instead", "page": None,
             "emb": [0.9, 0.1]},
            {"title": "SRS.pdf", "source_kind": "Requirements", "meeting_at": None, "version": 2,
             "indexed_at": 1795000000.0, "source_id": "s3", "evidence_id": "e3", "kind": "Requirement",
             "text": "Data stays in Egypt", "quote": "hosted in Egypt", "page": 4, "emb": [0.8, 0.2]}]

    def search(self):
        with mock.patch("syntrace_ai.graph.query_engine.run_query", return_value=self.ROWS):
            return kw.search_knowledge("which database", AccessContext("c1", ("SYNT",), None, ("p1",)),
                                       min_score=0.0, embed=lambda t: [[1.0, 0.0]])

    def test_newest_first_even_when_the_older_is_closer(self):
        hits = self.search()
        self.assertEqual([h["evidence_id"] for h in hits], ["e3", "e2", "e1"])   # 2026-11-18, 11-15, 10-01
        self.assertEqual([h["date"] for h in hits], ["2026-11-18", "2026-11-15", "2026-10-01"])

    def test_context_names_type_title_date_and_the_rule(self):
        context = kw.knowledge_context(self.search())
        self.assertIn("newest is the current decision", context)
        self.assertIn('"Follow-up" (meeting, 2026-11-15, version 1)', context)
        self.assertIn('"Kickoff" (meeting, 2026-10-01, version 1)', context)
        self.assertIn('"SRS.pdf" (requirements note, approved 2026-11-18, page 4, version 2)', context)
        self.assertLess(context.index("Follow-up"), context.index("Kickoff"))


class SourceRegressionTests(unittest.TestCase):
    """SYNT-569 regression: meeting-only, Jira-only and mixed questions through the agent's search tool."""

    def walk(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(AccessContext("c1", ("SYNT",), None, ("p1",)), "q")
        return walk

    MEETING = {"uid": "m1", "title": "Client sync", "type": "online", "date": "2026-11-18", "project": "SYNT",
               "items": [{"type": "requirement", "text": "Export to Excel", "links": [{"key": "SYNT-12", "url": "u"}]}],
               "score": 0.8, "excerpt": "they want Excel export"}
    KNOWLEDGE = {"title": "SRS.pdf", "source_kind": "Requirements", "meeting_at": None, "date": "2026-11-20",
                 "version": 1, "source_id": "s3", "evidence_id": "e3", "kind": "Requirement",
                 "text": "Data stays in Egypt", "quote": "hosted in Egypt", "page": 4, "score": 0.7}

    def test_meeting_only(self):
        walk = self.walk()
        with mock.patch("syntrace_ai.meetings.meeting_notes.search_meetings", return_value=[self.MEETING]), \
                mock.patch("syntrace_ai.workers.knowledge_worker.search_knowledge", return_value=[]):
            out = walk.search_meetings({"query": "excel"})
        self.assertIn("Client sync", out)
        self.assertIn("2026-11-18", out)
        self.assertIn("SYNT-12", walk.urls)

    def test_jira_only_question_finds_no_meeting(self):
        walk = self.walk()
        with mock.patch("syntrace_ai.meetings.meeting_notes.search_meetings", return_value=[]), \
                mock.patch("syntrace_ai.workers.knowledge_worker.search_knowledge", return_value=[]):
            self.assertEqual(walk.search_meetings({"query": "status of SYNT-12"}), "No approved meeting notes match.")

    def test_mixed_meeting_and_document(self):
        walk = self.walk()
        with mock.patch("syntrace_ai.meetings.meeting_notes.search_meetings", return_value=[self.MEETING]), \
                mock.patch("syntrace_ai.workers.knowledge_worker.search_knowledge", return_value=[self.KNOWLEDGE]):
            out = walk.search_meetings({"query": "client requirements"})
        self.assertIn("Client sync", out)
        self.assertIn("SRS.pdf", out)
        self.assertIn("page 4", out)
        self.assertEqual(walk.meetings, {"Client sync", "SRS.pdf"})
