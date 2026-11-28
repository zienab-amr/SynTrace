"""Requirement memory: the story of a requirement across meetings (offline parts)."""
import unittest

from syntrace_ai.meetings import memory as rm
from syntrace_ai.graph.query_engine import AccessContext


class ReplayTests(unittest.TestCase):
    def test_story_in_order(self):
        changes = [{"type": "modified", "after": "Email and Google login", "at": "2026-11-12"},
                   {"type": "created", "after": "Email login only", "at": "2026-11-05"},
                   {"type": "dropped", "after": "Email and Google login", "at": "2026-11-19"}]
        self.assertEqual(rm.replay(changes), ("Email and Google login", "dropped"))

    def test_restored_and_edited(self):
        changes = [{"type": "created", "after": "Dark mode", "at": "1"}, {"type": "dropped", "after": "Dark mode", "at": "2"},
                   {"type": "restored", "after": "Dark mode on mobile", "at": "3"},
                   {"type": "edited", "after": "Dark mode on the mobile app", "at": "4"}]
        self.assertEqual(rm.replay(changes), ("Dark mode on the mobile app", "active"))

    def test_creating_meeting_deleted_the_first_left_is_the_start(self):
        self.assertEqual(rm.replay([{"type": "modified", "after": "Email and Google login", "at": "2"}]),
                         ("Email and Google login", "active"))


class PlanTests(unittest.TestCase):
    REQ = {"uid": "r1", "text": "Email login only", "status": "active"}

    def test_new_requirement_is_created(self):
        self.assertEqual(rm.plan_changes({"type": "requirement", "relation": "new"}, []), [("create", None, "created")])

    def test_change_updates_the_earlier_requirement(self):
        self.assertEqual(rm.plan_changes({"type": "requirement", "relation": "change"}, [self.REQ]),
                         [("update", "r1", "modified")])

    def test_conflict_the_approved_word_wins(self):
        self.assertEqual(rm.plan_changes({"type": "requirement", "relation": "conflict"}, [self.REQ]),
                         [("update", "r1", "modified")])

    def test_client_drops_it(self):
        self.assertEqual(rm.plan_changes({"type": "decision", "relation": "dropped"}, [self.REQ]),
                         [("update", "r1", "dropped")])

    def test_asked_again_after_being_dropped(self):
        dropped = dict(self.REQ, status="dropped")
        self.assertEqual(rm.plan_changes({"type": "requirement", "relation": "existing"}, [dropped]),
                         [("update", "r1", "restored")])
        self.assertEqual(rm.plan_changes({"type": "requirement", "relation": "change"}, [dropped]),
                         [("update", "r1", "restored")])

    def test_said_again_only_links(self):
        self.assertEqual(rm.plan_changes({"type": "requirement", "relation": "existing"}, [self.REQ]),
                         [("link", "r1", None)])

    def test_a_decision_without_an_earlier_requirement_is_not_a_requirement(self):
        self.assertEqual(rm.plan_changes({"type": "decision", "relation": "new"}, []), [])

    def test_change_without_a_known_requirement_starts_one(self):
        self.assertEqual(rm.plan_changes({"type": "requirement", "relation": "change"}, []),
                         [("create", None, "created")])


class HistoryTests(unittest.TestCase):
    ROWS = [{"req": {"uid": "r1", "text": "Email login only", "status": "active", "project_key": "SYNT",
                     "updated_at": "2026-11-19"},
             "changes": [{"type": "created", "after": "Email login only", "at": "2026-11-05", "meeting": "Kickoff",
                          "meeting_date": "2026-11-05", "quote": "عايزين login بالايميل بس"},
                         {"type": "modified", "before": "Email login only", "after": "Email and Google login",
                          "at": "2026-11-12", "meeting": "Sprint 1 Review", "meeting_date": "2026-11-12",
                          "quote": "وكمان بجوجل", "note": "In Kickoff (2026-11-05) email only; now Google too."},
                         {"type": "dropped", "before": "Email and Google login", "after": "Email and Google login",
                          "at": "2026-11-19", "meeting": "Scope Freeze", "meeting_date": "2026-11-19"},
                         {"type": "edited", "before": "x", "after": "Email login only", "at": "2026-11-20T10:00:00Z",
                          "by": "emp-7"}]},
            {"req": {"uid": "r2", "text": "Pay by card", "status": "active", "project_key": "SYNT",
                     "updated_at": "2026-11-01"}, "changes": []}]
    CTX = AccessContext("c1", ("SYNT",))

    def test_question_finds_its_requirement(self):
        found = rm.history(self.CTX, lambda *a, **k: self.ROWS, question="what happened with the Google login?")
        self.assertEqual([r["uid"] for r in found], ["r1"])

    def test_story_names_meetings_and_dates_in_order(self):
        context = rm.history_context(rm.history(self.CTX, lambda *a, **k: self.ROWS, question="login"))
        lines = context.splitlines()
        self.assertIn('Kickoff (2026-11-05): asked for "Email login only"', lines[2])
        self.assertIn('Sprint 1 Review (2026-11-12): changed it to "Email and Google login"', lines[3])
        self.assertIn("In Kickoff (2026-11-05) email only; now Google too.", lines[3])
        self.assertIn("Scope Freeze (2026-11-19): dropped it", lines[4])
        self.assertIn('a team member (emp-7, 2026-11-20): reworded it as "Email login only"', lines[5])

    def test_nothing_matches(self):
        self.assertEqual(rm.history_context([]), "No requirement history matches.")

    def test_open_questions_tool_names_where_each_was_asked(self):
        from unittest import mock
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(AccessContext("c1", ("SYNT",)), "what should we ask next meeting")
        rows = [{"uid": "q1", "text": "iOS only or Android too?", "quote": "لسه مش عارفين", "meeting": "Kickoff",
                 "date": "2026-11-05", "project": "SYNT"}]
        with mock.patch("syntrace_ai.meetings.meeting_notes.run_query", lambda *a, **k: rows):
            out = walk.open_questions({"project": "synt"})
        self.assertIn("iOS only or Android too? (asked in Kickoff, 2026-11-05", out)
        self.assertEqual(walk.meetings, {"Kickoff"})
        with mock.patch("syntrace_ai.meetings.meeting_notes.run_query", lambda *a, **k: []):
            self.assertIn("No open question", walk.open_questions({}))
        with mock.patch("syntrace_ai.meetings.meeting_notes.run_query", lambda *a, **k: rows):   # a project outside the list is not asked for
            walk.open_questions({"project": "OTHER"})


if __name__ == "__main__":
    unittest.main()


class AgentToolTests(unittest.TestCase):
    def test_tool_tells_the_story_and_names_the_meetings(self):
        from unittest import mock
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(AccessContext("c1", ("SYNT",)), "what happened with google login")
        rows = HistoryTests.ROWS
        with mock.patch("syntrace_ai.meetings.meeting_notes.run_query", lambda *a, **k: rows):
            out = walk.requirement_history({"query": "google login"})
        self.assertIn("Sprint 1 Review (2026-11-12): changed it to", out)
        self.assertEqual(walk.meetings, {"Kickoff", "Sprint 1 Review", "Scope Freeze"})
        names = [t["function"]["name"] for t in graph_agent.TOOLS]
        self.assertIn("requirement_history", names)

    def test_tool_down_says_so(self):
        from unittest import mock
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(AccessContext("c1", ("SYNT",)), "q")
        with mock.patch("syntrace_ai.meetings.meeting_notes.run_query", side_effect=RuntimeError("down")):
            self.assertEqual(walk.requirement_history({}), "Requirement history is unavailable.")
