"""The meeting notes as an editable text (meetings/document.py), the agent's rewrite, the PDF and the API."""
import os
import unittest
from unittest.mock import patch

from syntrace_ai.meetings import meeting_notes as mn
from syntrace_ai.meetings import document as doc
from syntrace_ai.meetings import notes
from syntrace_ai.graph.query_engine import AccessContext

ITEMS = [{"uid": "a", "type": "requirement", "text": "Users log in with email.", "priority": "high"},
         {"uid": "b", "type": "decision", "text": "Role permissions are handled by the backend."},
         {"uid": "c", "type": "action_item", "text": "Send the design.", "owner": "Fatma", "due": "الخميس"},
         {"uid": "e", "type": "requirement", "text": "Dark mode."}]


def text():
    return notes.build("Kickoff.", "- Design.", ITEMS, ["e"])


PROPOSAL_ITEMS = ITEMS[:3] + [
    {"uid": "p", "type": "requirement", "text": "Proposed: Add a sofa clip to the remote.", "needs_review": True},
    {"uid": "q", "type": "decision", "text": "Proposed: Ship the beta on Friday.", "needs_review": True}]


class ProposalSectionTests(unittest.TestCase):
    """SYNT-1040: unsettled proposals sit in their own section, apart from what was asked for or agreed."""

    def notes(self):
        return notes.build("Kickoff.", "## Design\n- palettes", PROPOSAL_ITEMS)

    def test_proposals_are_listed_apart_without_the_mark(self):
        sections = dict(doc.sections(self.notes()))
        self.assertEqual(sections["Requirements"], ["Users log in with email. (priority: high)"])
        self.assertEqual(sections["Proposals to review"],
                         ["Add a sofa clip to the remote. (requirement; needs review)",
                          "Ship the beta on Friday. (decision; needs review)"])
        self.assertNotIn("Proposed:", self.notes())

    def test_untouched_notes_change_nothing(self):
        plan = doc.diff(PROPOSAL_ITEMS, self.notes())
        self.assertEqual((plan["changed"], plan["added"], plan["removed"]), ([], [], []))

    def test_rewording_a_proposal_keeps_it_a_proposal(self):
        plan = doc.diff(PROPOSAL_ITEMS, self.notes().replace("sofa clip", "sofa grip"))
        self.assertEqual(plan["changed"], [{"uid": "p", "text": "Proposed: Add a sofa grip to the remote."}])

    def test_moving_a_proposal_under_its_type_accepts_it(self):
        edited = self.notes().replace("- Add a sofa clip to the remote. (requirement; needs review)\n", "")
        edited = edited.replace("Decisions", "Requirements\n- Add a sofa clip to the remote.\nDecisions", 1) \
            if "Requirements" not in edited else edited.replace(
                "- Users log in with email. (priority: high)",
                "- Users log in with email. (priority: high)\n- Add a sofa clip to the remote.")
        plan = doc.diff(PROPOSAL_ITEMS, edited)
        self.assertEqual(plan["changed"], [{"uid": "p", "needs_review": False, "text": "Add a sofa clip to the remote."}])
        self.assertEqual(plan["removed"], [])

    def test_deleting_a_proposal_line_removes_it(self):
        edited = self.notes().replace("- Ship the beta on Friday. (decision; needs review)", "")
        self.assertEqual(doc.diff(PROPOSAL_ITEMS, edited)["removed"], ["q"])

    def test_refresh_after_review_keeps_the_topics_and_rebuilds_the_items(self):
        approved = [dict(i) for i in PROPOSAL_ITEMS if i["uid"] not in ("b", "q")]   # b and q deleted in review
        approved[-1].update(text="Add a sofa clip to the remote.", needs_review=False)   # p accepted
        text = notes.refresh(self.notes(), approved)
        self.assertTrue(text.startswith("Overview\n- Kickoff.\nTopics discussed\nDesign\n- palettes"))
        sections = dict(doc.sections(text))
        self.assertIn("Add a sofa clip to the remote.", sections["Requirements"])
        self.assertNotIn("Decisions", sections)
        self.assertNotIn("Proposals to review", sections)
        self.assertNotIn("Ship the beta", text)

    def test_a_topic_named_like_the_section_does_not_cut_the_refresh(self):
        text = notes.build("Kickoff.", "## Proposals to review\n- the sofa idea", PROPOSAL_ITEMS)
        self.assertIn("Topic: Proposals to review\n- the sofa idea", notes.refresh(text, PROPOSAL_ITEMS))


class DiffTests(unittest.TestCase):
    def test_nothing_edited_changes_nothing(self):
        plan = doc.diff(ITEMS, text())
        self.assertEqual((plan["changed"], plan["added"], plan["removed"]), ([], [], []))

    def test_a_reworded_line_changes_its_item(self):
        plan = doc.diff(ITEMS, text().replace("Users log in with email.", "Users log in with email or phone."))
        self.assertEqual(plan["changed"], [{"uid": "a", "text": "Users log in with email or phone."}])

    def test_details_in_brackets_change_the_item(self):
        plan = doc.diff(ITEMS, text().replace("owner: Fatma", "owner: Rodaina").replace("priority: high", "priority: low"))
        self.assertEqual(sorted(plan["changed"], key=lambda c: c["uid"]),
                         [{"uid": "a", "priority": "low"}, {"uid": "c", "owner": "Rodaina"}])

    def test_a_new_line_is_an_item_the_user_added(self):
        plan = doc.diff(ITEMS, text() + "\nBlockers\n- The server is down.")
        self.assertEqual(plan["added"], [{"type": "blocker", "text": "The server is down."}])

    def test_a_deleted_line_removes_its_item_and_out_of_scope_keeps_its_items(self):
        edited = text().replace("Decisions\n- Role permissions are handled by the backend.\n", "")
        plan = doc.diff(ITEMS, edited)
        self.assertEqual(plan["removed"], ["b"])   # "Dark mode." stays: it is under Out of scope

    def test_the_overview_is_the_summary(self):
        plan = doc.diff(ITEMS, text().replace("- Kickoff.", "- Kickoff of the delivery app."))
        self.assertEqual(plan["summary"], "Kickoff of the delivery app.")

    def test_numbers_the_agent_brought(self):
        self.assertEqual(doc.new_numbers("Results in under 2 seconds, 50 users.", "under 2 seconds"), ["50"])

    def test_a_number_said_in_words_is_not_new(self):
        self.assertEqual(doc.new_numbers("Login within 3 seconds.", "ولازم يخلص في أقل من تلات تواني"), [])
        self.assertEqual(doc.new_numbers("Up to two minutes, 5 tries.", "under two minutes"), ["5"])


class RewriteTests(unittest.TestCase):
    def test_a_proposal_is_not_saved_and_new_numbers_are_flagged(self):
        ctx = AccessContext("acme", ("DEL",))
        with patch.object(mn, "document", return_value={"text": text()}), \
                patch.object(mn, "run_query", return_value=[{"text": "Client: login by email please"}]):
            out = mn.rewrite_document(ctx, "s1", "make the login clearer",
                                      llm=lambda p: "- Users log in with their email in under 3 seconds.")
        self.assertEqual(out["proposal"], "- Users log in with their email in under 3 seconds.")
        self.assertEqual(out["warnings"], ["3 is not in the notes or the meeting"])

    def test_an_empty_request_is_refused(self):
        with self.assertRaises(mn.MeetingError):
            mn.rewrite_document(AccessContext("acme", ("DEL",)), "s1", "  ", llm=lambda p: "x")


class PdfTests(unittest.TestCase):
    def test_the_pdf_has_the_header_and_the_notes(self):
        from syntrace_ai.meetings import meeting_pdf
        from pypdf import PdfReader
        import io
        data = meeting_pdf.build("DEL", "Client sync", "2026-11-20", text())
        page = PdfReader(io.BytesIO(data)).pages[0].extract_text()
        for words in ("Meeting Requirements", "Project: DEL", "Users log in with email.", "Out of scope"):
            self.assertIn(words, page)

    def test_the_pdf_has_no_review_marks(self):
        from syntrace_ai.meetings import meeting_pdf
        from pypdf import PdfReader
        import io
        notes_text = text().replace("- Dark mode.", "- Dark mode. (needs review)")
        page = PdfReader(io.BytesIO(meeting_pdf.build("DEL", "x", "2026-11-20", notes_text))).pages[0].extract_text()
        self.assertNotIn("needs review", page)
        self.assertIn("Dark mode.", page)

    def test_only_an_approved_meeting_gets_a_pdf(self):
        with patch.object(mn, "get_source", return_value={"source": {"status": mn.PENDING}, "items": []}):
            with self.assertRaises(mn.MeetingError) as caught:
                mn.requirements_pdf(AccessContext("acme", ("DEL",)), "s1")
        self.assertEqual(caught.exception.status, 409)


class ApiTests(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        from syntrace_ai.api import ai_service
        env = patch.dict(os.environ, {"AI_API_KEY": "doc-key"})
        env.start()
        self.addCleanup(env.stop)
        self.client, self.headers = TestClient(ai_service.app), {"X-Internal-Api-Key": "doc-key"}
        self.q = "?companyId=acme&allowedProjects=DEL"

    def test_get_the_document(self):
        with patch.object(mn, "document", return_value={"text": "Overview\n- x", "status": "pending_review",
                                                        "editedBy": None, "editedAt": None}):
            r = self.client.get("/meetings/s1/document" + self.q, headers=self.headers)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["text"], "Overview\n- x")

    def test_the_pdf_is_a_download(self):
        with patch.object(mn, "requirements_pdf", return_value=b"%PDF-1.4 test"):
            r = self.client.get("/meetings/s1/requirements.pdf" + self.q, headers=self.headers)
        self.assertEqual(r.headers["content-type"], "application/pdf")
        self.assertIn('filename="s1-requirements.pdf"', r.headers["content-disposition"])

    def test_rewrite_returns_the_proposal(self):
        with patch.object(mn, "rewrite_document", return_value={"proposal": "- y", "part": "all", "warnings": []}):
            r = self.client.post("/meetings/s1/document/rewrite", headers=self.headers,
                                 json={"companyId": "acme", "allowedProjects": ["DEL"], "instruction": "clearer"})
        self.assertEqual(r.json()["proposal"], "- y")

    def test_editing_an_approved_meeting_is_409(self):
        with patch.object(mn, "edit_document", side_effect=mn.MeetingError("only a meeting in review can be edited", 409)):
            r = self.client.put("/meetings/s1/document", headers=self.headers,
                                json={"companyId": "acme", "allowedProjects": ["DEL"], "text": "Overview\n- x"})
        self.assertEqual(r.status_code, 409)


if __name__ == "__main__":
    unittest.main()
