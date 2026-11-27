"""Meeting notes against a real Neo4j (and Ollama, when it is running).

  $env:NEO4J_INTEGRATION="1"; python -m unittest -v test_meeting_neo4j

Each test uses a random company and removes everything it wrote. The LLM is replaced by a fixed reply,
except in test_real_model_extracts_checked_items (MEETING_LLM=1).
"""
import json
import os
import unittest
import uuid
from unittest.mock import patch

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.graph import ingest
from syntrace_ai.meetings import meeting_notes as mn
from syntrace_ai.graph.query_engine import AccessContext, get_driver, run_query

READY = os.getenv("NEO4J_INTEGRATION") == "1" and bool(os.getenv("NEO4J_URI"))

TRANSCRIPT = """Client: محتاجين login بـ Google في الموبايل أبلكيشن، ده مهم لينا جدًا.
Zienab Amr: الـ webhook endpoints لسه مش متهندلة، ده واقف على SYNTECH-5.
Fatma saeedd: ممكن نستخدم Redis للكاش بس لسه مش متأكدين.
Client: وعايزين dark mode في الإعدادات.
Fatma saeedd: رقمي 0100 243 1647 لو حد محتاجني.
"""

REPLY = json.dumps({"items": [
    {"type": "requirement", "text": "Google login in the mobile app",
     "evidence": "محتاجين login بـ Google في الموبايل أبلكيشن"},
    {"type": "blocker", "text": "Webhook endpoints are not handled, blocking SYNTECH-5",
     "evidence": "الـ webhook endpoints لسه مش متهندلة، ده واقف على SYNTECH-5"},
    {"type": "open_question", "text": "Use Redis for caching?", "evidence": "ممكن نستخدم Redis للكاش",
     "needs_review": True},
    {"type": "requirement", "text": "Dark mode in settings", "evidence": "وعايزين dark mode في الإعدادات"},
    {"type": "decision", "text": "Use Facebook login", "evidence": "هنستخدم Facebook login"},
]}, ensure_ascii=False)


def ollama_up():
    try:
        mn.embed_texts(["ping"])
        return True
    except Exception:
        return False


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1 and an available Neo4j database")
class MeetingGraphTests(unittest.TestCase):
    def setUp(self):
        self.tenant = "meeting-test-" + uuid.uuid4().hex
        self.ctx = AccessContext(self.tenant, ("SYNTECH",))
        run_query("CREATE (:Project {uid: $t + ':p', tenant_id: $t, key: 'SYNTECH'}) "
                  "CREATE (:WorkItem {uid: $t + ':w5', tenant_id: $t, key: 'SYNTECH-5', project_key: 'SYNTECH', "
                  "summary: 'Webhook endpoints', url: 'https://jira.example/SYNTECH-5'}) "
                  "CREATE (:WorkItem {uid: $t + ':w6', tenant_id: $t, key: 'SYNTECH-6', project_key: 'SYNTECH', "
                  "summary: 'Dark theme', url: 'https://jira.example/SYNTECH-6'})", t=self.tenant)

    def tearDown(self):
        run_query("MATCH (n) WHERE n.tenant_id = $t DETACH DELETE n", t=self.tenant)

    def suggest_dark_theme(self, items, ctx):
        for item in items:
            item["suggested"] = ([{"uid": self.tenant + ":w6", "key": "SYNTECH-6", "url": None, "score": 0.72}]
                                 if "Dark" in item["text"] and not item["links"] else [])

    def process(self, source_id="m1", reply=REPLY, text=TRANSCRIPT):
        with patch.object(mn, "suggest_links", self.suggest_dark_theme):
            return mn.submit_source(self.ctx, source_id, "SYNTECH", "online", "Client sync", "2026-11-04",
                                    text=text, llm=lambda prompt: reply, inline=True)

    def chunk_text(self):
        rows = run_query("MATCH (:Source {tenant_id: $t})-[:HAS_CHUNK]->(c:SourceChunk) RETURN c.text AS text",
                         t=self.tenant)
        return "\n".join(r["text"] for r in rows)

    def fake_analysis(self, items, text, ctx, project, uid, llm):
        """What meeting_agent.analyze returns, fixed: one change with an earlier item and a draft."""
        for i in items:
            i.update(speaker="Client", relation="new", related_keys=[], related_earlier=[], relation_note=None)
        dark = next(i for i in items if "Dark" in i["text"])
        dark.update(relation="change", related_keys=["SYNTECH-6"], relation_note="adds a settings switch")
        draft = {"item_id": dark["id"], "title": "Add dark mode switch", "description": "d", "acceptance": ["a"],
                 "subtasks": [{"title": "Theme API", "tag": "backend", "assignee": "Zienab amr"}],
                 "estimate": {"story_points": 3.0, "hours": None, "based_on": ["SYNTECH-6"]}}
        return {"summary": "Client sync summary", "scope": {"agreed": [dark["id"]], "out_of_scope": [], "open": []},
                "drafts": [draft]}, None

    def test_a_ticket_made_from_a_draft_comes_back_linked(self):
        """SYNT-920: the backend creates the ticket with the draft's label; the webhook brings it back."""
        with patch("syntrace_ai.meetings.meeting_agent.analyze", self.fake_analysis):
            view = self.process()
        dark = next(i for i in view["items"] if "Dark" in i["text"])
        draft = dark["drafts"][0]
        self.assertEqual(draft["jira_label"], mn.jira_label(draft["uid"]))
        mn.review_source(self.ctx, "m1", approve=[dark["uid"], draft["uid"]], reviewer="po-1")
        issue = {"id": "9001", "key": "SYNTECH-77", "fields": {
            "summary": "Add dark mode switch", "labels": ["from-meeting", draft["jira_label"]],
            "project": {"key": "SYNTECH"}, "status": {"name": "To Do", "statusCategory": {"key": "new"}},
            "issuetype": {"name": "Story"}, "updated": "2026-11-26T10:00:00.000+0000"}}
        with get_driver().session() as session:
            session.execute_write(lambda tx: ingest.upsert_issue_detailed(tx, issue, self.tenant, payload_mode="full"))
        view = mn.get_source(self.ctx, "m1")
        draft = next(i for i in view["items"] if "Dark" in i["text"])["drafts"][0]
        self.assertEqual((draft["status"], draft["jira_key"]), ("published", "SYNTECH-77"))
        rows = run_query("MATCH (:DraftTask {tenant_id: $t})-[:PUBLISHED_AS]->(w:WorkItem) RETURN w.key AS key",
                         t=self.tenant)
        self.assertEqual([r["key"] for r in rows], ["SYNTECH-77"])

    def test_analysis_and_drafts_are_stored_reviewed_and_deleted(self):
        with patch("syntrace_ai.meetings.meeting_agent.analyze", self.fake_analysis):
            view = self.process()
        source, items = view["source"], view["items"]
        self.assertEqual(source["summary"], "Client sync summary")
        dark = next(i for i in items if "Dark" in i["text"])
        self.assertEqual(source["scope"]["agreed"], [dark["uid"]])
        self.assertEqual((dark["speaker"], dark["relation"], dark["related_keys"]), ("Client", "change", ["SYNTECH-6"]))
        self.assertEqual(dark["drafts"][0]["title"], "Add dark mode switch")
        self.assertEqual(dark["drafts"][0]["subtasks"][0]["assignee"], "Zienab amr")
        draft_id = dark["drafts"][0]["uid"]

        # Approving the draft keeps it; deleting its item deletes it too.
        view = mn.review_source(self.ctx, "m1", approve=[draft_id], reviewer="po-1")
        dark = next(i for i in view["items"] if "Dark" in i["text"])
        self.assertEqual(dark["drafts"][0]["status"], "approved")
        mn.review_source(self.ctx, "m1", delete=[dark["uid"]], reviewer="po-1")
        self.assertEqual(run_query("MATCH (d:DraftTask {tenant_id: $t}) RETURN count(d) AS n", t=self.tenant)[0]["n"], 0)

    def test_drafts_go_with_their_source_and_stay_on_jira_disconnect(self):
        with patch("syntrace_ai.meetings.meeting_agent.analyze", self.fake_analysis):
            self.process()
        with get_driver().session() as session:
            while session.execute_write(lambda tx: ingest.delete_tenant(tx, self.tenant, keep_labels=ingest.MEETING_LABELS)):
                pass
        count = lambda: run_query("MATCH (d:DraftTask {tenant_id: $t}) RETURN count(d) AS n", t=self.tenant)[0]["n"]
        self.assertEqual(count(), 1)
        mn.delete_source(self.ctx, "m1")
        self.assertEqual(count(), 0)

    def test_earlier_items_are_linked_and_shown(self):
        old = self.process("old")
        mn.review_source(self.ctx, "old", approve=[i["uid"] for i in old["items"]], reviewer="po-1")
        earlier = run_query("MATCH (s:Source {tenant_id: $t, source_id: 'old'})-[:HAS_ITEM]->(i:MeetingItem) "
                            "RETURN i.uid AS uid LIMIT 1", t=self.tenant)[0]["uid"]

        def analysis(items, text, ctx, project, uid, llm):
            for i in items:
                i.update(relation="conflict", related_keys=[], related_earlier=[earlier], relation_note="n")
            return {"summary": None, "scope": {}, "drafts": []}, None
        with patch("syntrace_ai.meetings.meeting_agent.analyze", analysis):
            view = self.process("new")
        self.assertTrue(all(i["earlier"] and i["earlier"][0]["uid"] == earlier for i in view["items"]))
        self.assertEqual(view["items"][0]["earlier"][0]["date"], "2026-11-04")

    def test_full_lifecycle(self):
        result = self.process()
        self.assertEqual(result["source"]["status"], mn.PENDING)
        self.assertEqual(result["source"]["rejected_items"], 1)
        items = {i["text"]: i for i in result["items"]}
        self.assertEqual(len(items), 4)
        blocker = items["Webhook endpoints are not handled, blocking SYNTECH-5"]
        dark = items["Dark mode in settings"]
        redis = items["Use Redis for caching?"]
        google = items["Google login in the mobile app"]
        self.assertEqual(blocker["links"], [{"key": "SYNTECH-5", "url": "https://jira.example/SYNTECH-5"}])
        self.assertEqual([s["key"] for s in dark["suggested"]], ["SYNTECH-6"])
        self.assertEqual(dark["links"], [])
        self.assertTrue(redis["needs_review"])
        stored = run_query("MATCH (s:Source {tenant_id: $t}) RETURN s.text AS text", t=self.tenant)[0]["text"]
        self.assertNotIn("1647", stored)
        linked = run_query("MATCH (:Project {tenant_id: $t})-[:HAS_SOURCE]->(s:Source) RETURN count(s) AS n",
                           t=self.tenant)[0]["n"]
        self.assertEqual(linked, 1)

        # Re-sending while pending replaces the items, it does not duplicate them.
        self.assertEqual(len(self.process()["items"]), 4)
        items = {i["text"]: i for i in mn.get_source(self.ctx, "m1")["items"]}
        google, blocker = items["Google login in the mobile app"], items["Webhook endpoints are not handled, blocking SYNTECH-5"]
        dark, redis = items["Dark mode in settings"], items["Use Redis for caching?"]

        # Partly reviewed: still pending and not indexed.
        partial = mn.review_source(self.ctx, "m1", approve=[google["uid"]], reviewer="po-1")
        self.assertEqual(partial["source"]["status"], mn.PENDING)
        self.assertIsNone(partial["indexed"])

        # The reviewer confirms the suggested ticket for dark mode and deletes the Redis question.
        done = mn.review_source(self.ctx, "m1", approve=[blocker["uid"], dark["uid"]], delete=[redis["uid"]],
                                reviewer="po-1", links={dark["uid"]: ["SYNTECH-6"]}, inline=True)
        self.assertEqual(done["source"]["status"], mn.APPROVED)
        self.assertEqual(len(done["items"]), 3)
        self.assertTrue(all(i["status"] == "approved" for i in done["items"]))
        approved_dark = next(i for i in done["items"] if i["text"] == "Dark mode in settings")
        self.assertEqual([link["key"] for link in approved_dark["links"]], ["SYNTECH-6"])
        self.assertEqual(run_query("MATCH (:MeetingItem {tenant_id: $t})-[g:SUGGESTS]->() RETURN count(g) AS n",
                                   t=self.tenant)[0]["n"], 0)

        # The deleted item's sentence is not in the searchable text; the approved ones are.
        chunks = self.chunk_text()
        self.assertNotIn("Redis", chunks)
        self.assertIn("dark mode", chunks)
        self.assertIn("login بـ Google", chunks)

        with self.assertRaises(mn.MeetingError) as caught:
            self.process()
        self.assertEqual(caught.exception.status, 409)

        if done["indexed"]:
            hits = mn.search_meetings("Google login in the mobile app", self.ctx)
            self.assertEqual(hits[0]["title"], "Client sync")
            self.assertIn("Google login in the mobile app", mn.meetings_context(hits))
            self.assertNotIn("Redis", mn.meetings_context(mn.search_meetings("Redis cache", self.ctx)))
            self.assertEqual(mn.search_meetings("Google login", AccessContext(self.tenant, ("OTHER",))), [])
        else:
            self.assertFalse(ollama_up(), "Ollama is running, so the chunks should have been embedded")

        mn.delete_source(self.ctx, "m1")
        left = run_query("MATCH (n) WHERE n.tenant_id = $t AND (n:Source OR n:MeetingItem OR n:SourceChunk) "
                         "RETURN count(n) AS n", t=self.tenant)[0]["n"]
        self.assertEqual(left, 0)
        self.assertEqual(run_query("MATCH (w:WorkItem {tenant_id: $t}) RETURN count(w) AS n",
                                   t=self.tenant)[0]["n"], 2)

    def test_an_accepted_proposal_loses_its_mark_and_the_notes_follow_the_review(self):
        """SYNT-1040: approving a "Proposed:" item accepts it; the notes (and the PDF) drop deleted items."""
        reply = json.dumps({"items": [
            {"type": "requirement", "text": "Proposed: Dark mode in settings",
             "evidence": "وعايزين dark mode في الإعدادات", "needs_review": True},
            {"type": "requirement", "text": "Google login in the mobile app",
             "evidence": "محتاجين login بـ Google في الموبايل أبلكيشن"},
            {"type": "open_question", "text": "Use Redis for caching?", "evidence": "ممكن نستخدم Redis للكاش"},
        ]}, ensure_ascii=False)
        items = {i["text"]: i for i in self.process(reply=reply)["items"]}
        before = mn.document(self.ctx, "m1")["text"]
        self.assertIn("Proposals to review\n- Dark mode in settings (requirement; needs review)", before)
        dark, google = items["Proposed: Dark mode in settings"], items["Google login in the mobile app"]
        from syntrace_ai.assistant import llm_client
        plan_reply = json.dumps({"drafts": [{"for": "I1", "title": "Add dark mode to settings",
                                             "description": "A dark theme switch.", "acceptance": ["It switches."]}]})
        with patch.object(llm_client, "for_step", lambda step: (lambda prompt: plan_reply)):
            done = mn.review_source(self.ctx, "m1", approve=[dark["uid"], google["uid"]],
                                    delete=[items["Use Redis for caching?"]["uid"]], reviewer="po-1", inline=True)
        drafts = {r["title"] for r in run_query(
            "MATCH (:MeetingItem {uid: $u})-[:HAS_DRAFT]->(d:DraftTask) RETURN d.title AS title", u=dark["uid"])}
        self.assertEqual(drafts, {"Add dark mode to settings"})   # SYNT-1065: made once it was accepted
        self.assertEqual(done["source"]["status"], mn.APPROVED)
        texts = {i["text"]: i for i in done["items"]}
        self.assertIn("Dark mode in settings", texts)
        self.assertFalse(texts["Dark mode in settings"]["needs_review"])
        memory = {r["text"] for r in run_query("MATCH (r:Requirement {tenant_id: $t}) RETURN r.text AS text",
                                               t=self.tenant)}
        self.assertEqual(memory, {"Dark mode in settings", "Google login in the mobile app"})
        after = mn.document(self.ctx, "m1")["text"]
        self.assertNotIn("Proposals to review", after)
        self.assertNotIn("Redis", after.split("Requirements", 1)[1])
        self.assertIn("- Dark mode in settings", after)

    def test_every_item_deleted_leaves_nothing_searchable(self):
        items = self.process()["items"]
        result = mn.review_source(self.ctx, "m1", delete=[i["uid"] for i in items], reviewer="po-1", inline=True)
        self.assertEqual(result["source"]["status"], mn.APPROVED)
        self.assertEqual(self.chunk_text(), "")

    def test_failed_processing_is_stored_and_can_be_sent_again(self):
        failed = self.process(reply="sorry")
        self.assertEqual(failed["source"]["status"], mn.FAILED)
        self.assertIn("JSON", failed["source"]["error"])
        with self.assertRaises(mn.MeetingError) as caught:
            mn.review_source(self.ctx, "m1", reviewer="po-1")
        self.assertEqual(caught.exception.status, 409)
        again = self.process()
        self.assertEqual(again["source"]["status"], mn.PENDING)
        self.assertIsNone(again["source"]["error"])

    def test_processing_source_cannot_be_reviewed_but_can_be_deleted(self):
        with patch.object(mn, "_enqueue", lambda uid, job: None):
            queued = mn.submit_source(self.ctx, "p1", "SYNTECH", "note", "Note", None, text=TRANSCRIPT)
        self.assertEqual(queued["source"]["status"], mn.PROCESSING)
        self.assertEqual(queued["items"], [])
        with self.assertRaises(mn.MeetingError) as caught:
            mn.review_source(self.ctx, "p1", reviewer="po-1")
        self.assertEqual(caught.exception.status, 409)
        job = run_query("MATCH (s:Source {tenant_id: $t}) RETURN s.job_id AS job", t=self.tenant)[0]["job"]
        mn.delete_source(self.ctx, "p1")
        mn.process_job(mn.source_uid(self.tenant, "p1"), job, llm=lambda p: self.fail("deleted source was processed"))
        self.assertEqual(run_query("MATCH (n:Source {tenant_id: $t}) RETURN count(n) AS n", t=self.tenant)[0]["n"], 0)

    def test_other_company_or_project_cannot_read_review_or_delete(self):
        self.process()
        for ctx in (AccessContext("someone-else", ("SYNTECH",)), AccessContext(self.tenant, ("OTHER",))):
            for call in (lambda: mn.get_source(ctx, "m1"), lambda: mn.review_source(ctx, "m1"),
                         lambda: mn.delete_source(ctx, "m1")):
                with self.assertRaises(mn.MeetingError) as caught:
                    call()
                self.assertEqual(caught.exception.status, 404)
        with self.assertRaises(mn.MeetingError) as caught:   # nor overwrite it by sending the same id
            mn.submit_source(AccessContext(self.tenant, ("OTHER",)), "m1", "OTHER", "note", "x", text="hello there")
        self.assertEqual(caught.exception.status, 404)
        self.assertEqual(mn.get_source(self.ctx, "m1")["source"]["status"], mn.PENDING)

    def test_jira_disconnect_keeps_meeting_notes(self):
        self.process()
        with get_driver().session() as session:
            while session.execute_write(lambda tx: ingest.delete_tenant(tx, self.tenant,
                                                                         keep_labels=ingest.MEETING_LABELS)):
                pass
        counts = run_query("MATCH (n) WHERE n.tenant_id = $t RETURN labels(n)[0] AS label, count(n) AS n",
                           t=self.tenant)
        labels = {r["label"]: r["n"] for r in counts}
        self.assertEqual(set(labels), {"Source", "MeetingItem"})

    @unittest.skipUnless(os.getenv("MEETING_LLM") == "1", "set MEETING_LLM=1 to call the real Groq model")
    def test_real_model_extracts_checked_items(self):
        result = mn.submit_source(self.ctx, "llm1", "SYNTECH", "online", "Client sync", "2026-11-04",
                                  text=TRANSCRIPT, inline=True)
        print("\nreal model:", result["source"]["status"], result["source"].get("error"))
        print("real model items:", json.dumps(result["items"], ensure_ascii=False, indent=1))
        self.assertEqual(result["source"]["status"], mn.PENDING)
        types = {i["type"] for i in result["items"]}
        self.assertIn("requirement", types)
        self.assertNotIn("decision", {i["type"] for i in result["items"] if "Redis" in i["text"]})
        self.assertTrue(all("1647" not in i["evidence"] for i in result["items"]))
        self.assertTrue(all(mn.MASK not in i["text"] for i in result["items"]), "contact details became an item")
        copied = [i for i in result["items"] if mn.normalize(i["text"]) == mn.normalize(i["evidence"])]
        self.assertLess(len(copied), len(result["items"]), "every item text is a copy of its evidence")

    def test_source_with_no_items_is_approved_by_an_empty_review(self):
        mn.submit_source(self.ctx, "n1", "SYNTECH", "note", "Short note", None,
                         text="Nothing about the project here.", llm=lambda p: '{"items": []}', inline=True)
        self.assertEqual(mn.review_source(self.ctx, "n1", reviewer="pm-1", inline=True)["source"]["status"], mn.APPROVED)
        self.assertIn("Nothing about the project", self.chunk_text())


if __name__ == "__main__":
    unittest.main()
