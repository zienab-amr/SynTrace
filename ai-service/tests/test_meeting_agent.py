"""Offline tests for the meeting agent: speakers, comparison with the project, scope and drafts.
The model is faked; what is checked is that only references the code gave are kept."""
import json
import os
import unittest
from unittest.mock import patch

os.environ["AI_API_KEY"] = "test-key"

from syntrace_ai.meetings import meeting_agent as ma
from syntrace_ai.graph.query_engine import AccessContext

CTX = AccessContext("company-1", ("SYNTECH",))

WISPR = """martina Sameh: محتاجين الـ login يبقى بـ Google بس، من غير password.
Fatma Saeedd (You): تمام، وهنشيل الـ OTP اللي في SYNTECH-40.
martina Sameh: والـ dashboard يتعمله export لـ PDF."""


def item(n, type_, text, evidence, keys=(), earlier=()):
    return {"id": f"src:item:{n}", "type": type_, "text": text, "evidence": evidence, "links": [],
            "suggested": [], "candidate_keys": list(keys), "candidate_earlier": list(earlier), "needs_review": False}


DETAILS = {"SYNTECH-40": {"key": "SYNTECH-40", "summary": "Login with OTP", "type": "Story", "status": "In Progress",
                          "assignee": "Zienab amr", "description": "Users log in with a one time password.",
                          "custom_fields": json.dumps({"Story point estimate": 5}), "estimate_seconds": 7200},
           "SYNTECH-41": {"key": "SYNTECH-41", "summary": "Dashboard charts", "type": "Story", "status": "Done",
                          "assignee": "Rodaina", "description": None, "custom_fields": json.dumps({"Story Points": 3}),
                          "estimate_seconds": 18000}}
EARLIER = {"uid": "old:item:1", "type": "decision", "text": "Login uses OTP only", "date": "2026-11-01", "title": "Sync 1"}


class SpeakerTests(unittest.TestCase):
    def test_wispr_labels_give_the_speaker_without_you(self):
        items = [{"evidence": "هنشيل الـ OTP اللي في SYNTECH-40"}, {"evidence": "يتعمله export لـ PDF"},
                 {"evidence": "مش موجود خالص في الكلام"}]
        ma.attach_speakers(items, WISPR)
        self.assertEqual([i["speaker"] for i in items], ["Fatma Saeedd", "martina Sameh", None])


class CompareTests(unittest.TestCase):
    def test_only_given_references_are_kept(self):
        items = [item(1, "requirement", "Google login only", "الـ login يبقى بـ Google بس", ["SYNTECH-40"], [EARLIER]),
                 item(2, "requirement", "Export dashboard to PDF", "export لـ PDF", ["SYNTECH-41"]),
                 item(3, "action_item", "Remove OTP", "هنشيل الـ OTP", ["SYNTECH-40"])]
        reply = json.dumps({"items": [
            {"id": "I1", "relation": "conflict", "refs": ["E1", "syntech-40"], "note": "OTP was agreed before"},
            {"id": "I2", "relation": "change", "refs": ["SYNTECH-99"], "note": "invented key"},
            {"id": "I3", "relation": "existing", "refs": ["SYNTECH-40"], "note": "same as SYNTECH-40"},
            {"id": "I9", "relation": "new", "refs": []}]})
        ma.compare(items, DETAILS, "SYNTECH", lambda prompt: reply)
        self.assertEqual(items[0]["relation"], "conflict")
        self.assertEqual(items[0]["related_keys"], ["SYNTECH-40"])
        self.assertEqual(items[0]["related_earlier"], ["old:item:1"])
        self.assertTrue(items[0]["needs_review"])
        self.assertIsNone(items[1]["relation"])   # a key the code did not give is not trusted
        self.assertTrue(items[1]["needs_review"])
        self.assertEqual((items[2]["relation"], items[2]["related_keys"]), ("existing", ["SYNTECH-40"]))

    def test_nothing_to_compare_needs_no_model_call(self):
        items = [item(1, "requirement", "Voice commands", "voice commands")]
        ma.compare(items, {}, "SYNTECH", lambda prompt: self.fail("no references, so no call"))
        self.assertEqual(items[0]["relation"], "new")

    def test_prompt_lists_each_items_own_references(self):
        seen = []
        items = [item(1, "requirement", "Google login only", "Google بس", ["SYNTECH-40"], [EARLIER])]
        ma.compare(items, DETAILS, "SYNTECH", lambda prompt: seen.append(prompt) or "{}")
        self.assertIn("references: SYNTECH-40, E1", seen[0])
        self.assertIn("SYNTECH-40: Login with OTP", seen[0])
        self.assertIn("E1: [decision, 2026-11-01, Sync 1] Login uses OTP only", seen[0])


class PlanTests(unittest.TestCase):
    def setUp(self):
        self.items = [item(1, "requirement", "Export dashboard to PDF", "export لـ PDF", ["SYNTECH-41"]),
                      item(2, "decision", "Release notes in English", "English"),
                      item(3, "requirement", "Google login only", "Google بس", ["SYNTECH-40"])]
        self.items[0].update(relation="new", related_keys=[], relation_note=None)
        self.items[1].update(relation="new", related_keys=[], relation_note=None)
        self.items[2].update(relation="existing", related_keys=["SYNTECH-40"], relation_note="same")

    def run_plan(self, reply):
        with patch.object(ma, "project_tags", lambda ctx, p: ["backend", "flutter"]), \
                patch.object(ma, "tag_owners", lambda ctx, p, tags: {"backend": "Zienab amr", "flutter": "Rodaina"}):
            return ma.plan(self.items, CTX, "SYNTECH", DETAILS, lambda prompt: reply)

    def test_drafts_only_for_new_or_changed_requirements_with_known_tags(self):
        result = self.run_plan(json.dumps({
            "summary": "Client wants PDF export.",
            "scope": {"agreed": ["I1", "I2", "I7"], "out_of_scope": ["I3", "I1"], "open": []},
            "drafts": [{"for": "I1", "title": "Export dashboard to PDF", "description": "d", "acceptance": ["a PDF opens"],
                        "subtasks": [{"title": "PDF endpoint", "tag": "Backend"}, {"title": "Export button", "tag": "flutter"},
                                     {"title": "Design", "tag": "ux"}]},
                       {"for": "I2", "title": "Not a requirement"}, {"for": "I3", "title": "Already a ticket"}]}))
        self.assertEqual(result["scope"]["agreed"], ["src:item:1", "src:item:2"])   # I7 does not exist
        self.assertEqual(result["scope"]["out_of_scope"], ["src:item:3"])   # I1 placed once only
        self.assertEqual([d["item_id"] for d in result["drafts"]], ["src:item:1"])
        subtasks = result["drafts"][0]["subtasks"]
        self.assertEqual([(s["tag"], s["assignee"]) for s in subtasks],
                         [("backend", "Zienab amr"), ("flutter", "Rodaina"), (None, None)])
        self.assertEqual(result["drafts"][0]["estimate"], {"story_points": 3.0, "hours": 5.0, "based_on": ["SYNTECH-41"]})

    def test_a_bad_reply_gives_an_empty_plan(self):
        result = self.run_plan("sorry")
        self.assertEqual((result["drafts"], result["scope"]["agreed"]), ([], []))


class AnalyzeTests(unittest.TestCase):
    def test_a_failure_keeps_the_items_and_says_so(self):
        items = [item(1, "requirement", "x", "الـ login يبقى بـ Google بس")]
        with patch.object(ma, "find_candidates", side_effect=RuntimeError("bolt://secret")):
            analysis, error = ma.analyze(items, WISPR, CTX, "SYNTECH", "src", lambda p: "{}")
        self.assertEqual(analysis["drafts"], [])
        self.assertIn("analysis unavailable", error)
        self.assertNotIn("bolt", error)
        self.assertEqual(items[0]["speaker"], "martina Sameh")
        self.assertIsNone(items[0]["relation"])

    def test_estimate_is_the_median_of_similar_tickets(self):
        self.assertEqual(ma.estimate(["SYNTECH-40", "SYNTECH-41", "SYNTECH-99"], DETAILS),
                         {"story_points": 4.0, "hours": 3.5, "based_on": ["SYNTECH-40", "SYNTECH-41"]})
        self.assertEqual(ma.estimate([], DETAILS), {"story_points": None, "hours": None, "based_on": []})


class ContractTests(unittest.TestCase):
    def test_review_view_carries_the_analysis_in_camel_case(self):
        from fastapi.testclient import TestClient
        from syntrace_ai.api import ai_service
        view = {"source": {"source_id": "m1", "source_type": "online", "title": "t", "meeting_date": "2026-11-21",
                           "project_key": "SYNTECH", "status": "pending_review", "summary": "s",
                           "scope": {"agreed": ["a"], "out_of_scope": ["b"], "open": []}, "analysis_error": None},
                "items": [{"uid": "a", "type": "requirement", "text": "x", "evidence": "y", "owner": None, "due": None,
                           "needs_review": False, "status": "pending", "links": [], "suggested": [],
                           "speaker": "martina Sameh", "relation": "change", "related_keys": ["SYNTECH-40"],
                           "relation_note": "n", "earlier": [{"uid": "e", "type": "decision", "text": "t", "date": "d", "title": "x"}],
                           "drafts": [{"uid": "a:draft", "title": "T", "description": "D", "acceptance": ["A"],
                                       "subtasks": [{"title": "S", "tag": "backend", "assignee": "Zienab amr"}],
                                       "story_points": 3.0, "estimate_hours": 5.0, "estimate_based_on": ["SYNTECH-41"],
                                       "status": "pending"}]}]}
        with patch("syntrace_ai.meetings.meeting_notes.get_source", lambda ctx, sid: view):
            body = TestClient(ai_service.app).get("/meetings/m1?companyId=c&allowedProjects=SYNTECH",
                                                  headers={"X-Internal-Api-Key": "test-key"}).json()
        self.assertEqual(body["scope"], {"agreed": ["a"], "outOfScope": ["b"], "open": []})
        got = body["items"][0]
        self.assertEqual((got["speaker"], got["relation"], got["relatedKeys"]), ("martina Sameh", "change", ["SYNTECH-40"]))
        self.assertEqual(got["relatedEarlier"][0]["meetingDate"], "d")
        self.assertEqual(got["drafts"][0]["subtasks"][0]["assignee"], "Zienab amr")
        self.assertEqual(got["drafts"][0]["storyPoints"], 3.0)


if __name__ == "__main__":
    unittest.main()


class DraftableTests(unittest.TestCase):
    """SYNT-1065: drafts only for confirmed requirements."""

    def test_which_items_get_a_jira_draft(self):
        from syntrace_ai.meetings import meeting_agent as ma
        base = {"type": "requirement", "text": "Users log in with email.", "relation": "new"}
        self.assertTrue(ma.draftable_item(base))
        self.assertTrue(ma.draftable_item(dict(base, relation="change")))     # the newer version
        self.assertFalse(ma.draftable_item(dict(base, text="Proposed: Add dark mode.")))
        self.assertFalse(ma.draftable_item(dict(base, clarity="unclear")))   # a question for the client
        self.assertFalse(ma.draftable_item(dict(base, relation="dropped")))
        self.assertFalse(ma.draftable_item(dict(base, relation="existing")))
        self.assertFalse(ma.draftable_item(dict(base, type="decision")))

    def test_the_plan_asks_drafts_only_for_confirmed_requirements(self):
        import json
        from syntrace_ai.meetings import meeting_agent as ma
        from unittest.mock import patch
        items = [{"id": "a", "type": "requirement", "text": "Users log in with email.", "relation": "new"},
                 {"id": "b", "type": "requirement", "text": "Proposed: Add dark mode.", "relation": "new"}]
        seen = []

        def llm(prompt):
            seen.append(prompt)
            return json.dumps({"drafts": [{"for": "I1", "title": "Email login"}, {"for": "I2", "title": "Dark mode"}]})
        with patch.object(ma, "project_tags", lambda *a: []), patch.object(ma, "tag_owners", lambda *a: {}):
            out = ma.plan(items, None, "P", {}, llm)
        self.assertEqual([d["item_id"] for d in out["drafts"]], ["a"])
        self.assertIn("only for these items: I1.", seen[0])
