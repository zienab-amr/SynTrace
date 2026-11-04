"""Offline tests for: fixture tickets (attachments, worklogs, reassignments), search never
returning a deleted issue from the warm cache, and answering without intent regex."""
import glob
import json
import os
import unittest
from unittest.mock import patch

os.environ.setdefault("JIRA_SITE_ID", "fixture.atlassian.net")

import answer_generator as ag
import embeddings as em
import ingest
import phase3_fakes as pf
import query_engine as qe
import semantic_search as ss

T = "t"
SITE = "fixture.atlassian.net"
CTX = qe.AccessContext(T, ("FIX",))


def fixtures():
    out = {}
    for path in sorted(glob.glob(os.path.join(os.path.dirname(__file__) or ".", "test_fixtures", "*.json"))):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        out[data["key"]] = data
    return out


class FixtureIngestTests(unittest.TestCase):
    def setUp(self):
        self.tx = pf.GraphTx()
        for item in fixtures().values():
            self.assertEqual(ingest.upsert_issue(self.tx, item, T, payload_mode="full", site_id=SITE), "upserted")

    def nodes(self, label):
        return [v for (l, _u), v in self.tx.entities.items() if l == label]

    def test_attachments_keep_metadata_and_media_kind(self):
        atts = {a["filename"]: a for a in self.nodes("Attachment")}
        self.assertEqual(set(atts), {"login-screen.png", "bug-demo.mp4", "cases.pdf", "crash.jpg"})
        self.assertEqual(atts["login-screen.png"]["mimeType"], "image/png")
        self.assertEqual(atts["bug-demo.mp4"]["mimeType"], "video/mp4")
        self.assertTrue(atts["bug-demo.mp4"]["content_url"].endswith("/2"))

    def test_worklogs_are_stored(self):
        self.assertEqual(sorted(w["timeSpentSeconds"] for w in self.nodes("Worklog")), [3600, 7200])

    def test_reassignments_have_every_column_the_history_query_reads(self):
        rows = [c for c in self.nodes("ChangeEvent") if c.get("field") == "assignee"]
        self.assertEqual(len(rows), 3)
        moved = next(c for c in rows if c.get("to_name") == "Salma Fixture")
        self.assertEqual(moved["from_name"], "Amr Fixture")
        self.assertEqual(moved["author"], "Mona Fixture")
        self.assertTrue(moved["changed_at"])

    def test_replay_adds_nothing(self):
        before = dict(self.tx.entities)
        for item in fixtures().values():
            ingest.upsert_issue(self.tx, item, T, payload_mode="full", site_id=SITE)
        self.assertEqual(set(before), set(self.tx.entities))


class SearchAfterDeleteTests(unittest.TestCase):
    def setUp(self):
        ss._CACHE.clear()
        self.live = {"u1", "u2"}

    def fake_query(self, query, **p):
        if "w.embedding" in query:
            return [{"uid": u, "rkey": k, "summary": k, "status": "s", "url": None, "project": "FIX",
                     "assignee": None, "emb": [1.0, 0.0]} for u, k in (("u1", "FIX-1"), ("u2", "FIX-2"))]
        return [{"uid": u} for u in p["uids"] if u in self.live]

    def test_issue_deleted_while_cache_is_warm_is_not_returned(self):
        with patch.object(ss, "run_query", self.fake_query), patch.object(ss, "embed_texts", lambda t: [[1.0, 0.0]]):
            self.assertEqual({h["key"] for h in ss.semantic_search("q", CTX)}, {"FIX-1", "FIX-2"})
            self.live.discard("u1")
            self.assertEqual({h["key"] for h in ss.semantic_search("q", CTX)}, {"FIX-2"})


class AnswerWithoutIntentRegexTests(unittest.TestCase):
    CARD = {"key": "FIX-1", "summary": "Parent", "status": "En cours", "assignee": "Salma", "priority": "High",
            "project": "FIX", "url": "http://x/FIX-1", "sprints": []}
    DETAILS = {**CARD, "attachments": [{"filename": "login-screen.png", "mime": "image/png", "author": "Amr",
                                        "created": "2026-09-02"}],
               "assignment_history": [{"at": "2026-09-05", "from": "Amr", "to": "Salma", "by": "Mona"}],
               "worklogs": [{"author": "Salma", "seconds": 7200, "entries": 1},
                            {"author": "Amr", "seconds": 5400, "entries": 2}]}
    BLOCKER = {"key": "FIX-1", "items": [{"key": "FIX-9", "summary": "Blocker", "status": "Open", "assignee": "Amr",
                                          "url": "http://x/FIX-9"}]}

    def run_q(self, question, llm_answer):
        seen = {}

        def llm(q, context, style="short"):
            seen["context"] = context
            return llm_answer

        rel = {"blockers": lambda k, c: self.BLOCKER,
               "blocks": lambda k, c: {"key": k, "items": [{"key": "FIX-8", "summary": "Blocked", "status": "Open",
                                                            "assignee": "Amr", "url": "http://x/FIX-8"}]},
               "related": lambda k, c: {"key": k, "items": []}}
        with patch.object(ag, "answer_key_question", lambda q, c: [{"type": "found", "card": self.CARD}]), \
                patch.object(ag, "get_ticket_details", lambda k, c: self.DETAILS), \
                patch.object(ag, "RELATION_FETCHERS", rel), patch.object(ag, "call_llm", llm):
            return ag.generate_answer(question, CTX), seen["context"]

    def test_same_context_for_english_and_arabic_questions(self):
        _, english = self.run_q("What blocks FIX-1?", "FIX-9 blocks FIX-1.")
        _, arabic = self.run_q("إيه اللي مانع FIX-1؟", "FIX-9 مانعة FIX-1.")
        self.assertEqual(english, arabic)
        self.assertIn("tickets that block this ticket", arabic)
        self.assertIn("FIX-9", arabic)
        self.assertIn("login-screen.png", arabic)
        self.assertIn("Amr -> Salma", arabic)

    def test_arabic_answer_is_kept_and_blocker_gets_a_link(self):
        answer, _ = self.run_q("إيه اللي مانع FIX-1؟", "FIX-9 مانعة FIX-1.")
        self.assertIn("FIX-9 مانعة FIX-1.", answer)
        self.assertIn("FIX-9: http://x/FIX-9", answer)

    def test_time_logged_reaches_the_llm_and_the_fallback(self):
        answer, context = self.run_q("How much time was logged on FIX-1?", "3.5h on FIX-1.")
        self.assertIn("Time logged: 3.5h total", context)
        self.assertIn("Salma: 2h in 1 entries", context)
        self.assertIn("3.5h on FIX-1.", answer)
        fallback, _ = self.run_q("How much time was logged on FIX-1?", None)
        self.assertIn("Time logged: 3.5h", fallback)

    def test_only_tickets_named_in_the_reply_get_links(self):
        answer, _ = self.run_q("What blocks FIX-1?", "FIX-9 blocks FIX-1.")
        self.assertIn("FIX-1: http://x/FIX-1", answer)
        self.assertIn("FIX-9: http://x/FIX-9", answer)
        self.assertNotIn("FIX-8", answer)

    def test_empty_relationship_is_stated_to_the_llm(self):
        _, context = self.run_q("What is related to FIX-1?", "FIX-1 has none.")
        self.assertIn("tickets related to this ticket", context)
        self.assertIn("None found", context)

    def test_invented_key_falls_back_to_template_with_relations(self):
        answer, _ = self.run_q("What blocks FIX-1?", "FIX-777 blocks it.")
        self.assertNotIn("FIX-777", answer)
        self.assertIn("is blocked by", answer)
        self.assertIn("Attachments: 1", answer)

    def test_llm_down_still_answers(self):
        answer, _ = self.run_q("What blocks FIX-1?", None)
        self.assertIn("FIX-1", answer)


class FakeOllama:
    """Rejects any request holding a text with BAD in its first `reject_up_to` characters."""
    def __init__(self, reject_up_to=10**9):
        self.reject_up_to, self.calls = reject_up_to, []

    def __call__(self, url, json=None, timeout=None):
        self.calls.append(json["input"])
        bad = any("BAD" in t[:self.reject_up_to] for t in json["input"])
        resp = type("R", (), {})()
        resp.ok, resp.status_code = not bad, 500 if bad else 200
        resp.text = "model failed" if bad else ""
        resp.json = lambda: {"embeddings": [[1.0, 0.0] for _ in json["input"]]}
        return resp


class EmbeddingBatchTests(unittest.TestCase):
    def run_batches(self, texts, fake, size=2):
        with patch.object(em.requests, "post", fake):
            return [item for item in em.embed_batches(texts, batch_size=size)]

    def test_one_bad_text_does_not_stop_the_others(self):
        out = self.run_batches(["ok1", "BAD", "ok3"], FakeOllama())
        self.assertEqual(out[0][1], [[1.0, 0.0], None])
        self.assertIn("HTTP 500: model failed", out[0][2][1])
        self.assertEqual(out[1][1], [[1.0, 0.0]])

    def test_long_text_is_retried_shorter(self):
        text = "x" * 1500 + "BAD"
        out = self.run_batches([text], FakeOllama(reject_up_to=1200))
        self.assertIsNotNone(out[0][1][0])

    def test_unreachable_ollama_raises(self):
        def down(*a, **k):
            raise em.requests.ConnectionError("refused")
        with patch.object(em.requests, "post", down):
            with self.assertRaises(em.EmbeddingError):
                list(em.embed_batches(["a"]))

    def test_non_finite_vector_is_a_failure(self):
        def nan(url, json=None, timeout=None):
            r = type("R", (), {"ok": True, "status_code": 200, "text": ""})()
            r.json = lambda: {"embeddings": [[float("nan")] for _ in json["input"]]}
            return r
        with patch.object(em.requests, "post", nan):
            out = list(em.embed_batches(["a"]))
        self.assertEqual(out[0][1], [None])


if __name__ == "__main__":
    unittest.main()
