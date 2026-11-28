"""Risks as grounded facts (SYNT-909) and the helper model that picks tool result lines (SYNT-910)."""
import os
import json
import unittest
from unittest.mock import patch

from syntrace_ai.assistant import graph_agent as ga
from syntrace_ai.assistant import llm_client
from syntrace_ai.graph.query_engine import AccessContext

CTX = AccessContext("acme", ("DEL",))


class ProjectRisksTests(unittest.TestCase):
    def test_every_source_is_read_and_cut_short(self):
        walk = ga.Walk(CTX, "what could go wrong in DEL?")
        long = "x" * 2000
        with patch.object(walk, "find_blocked", return_value="DEL-3 is blocked by DEL-1"), \
                patch.object(walk, "find_stuck", return_value=long), \
                patch.object(walk, "jira_vs_github", return_value="No GitHub repository is available to this user."), \
                patch.object(walk, "uncovered_requirements", side_effect=RuntimeError("down")), \
                patch.object(walk, "open_questions", return_value="Open questions from meetings: - Which payments?"):
            text = walk.project_risks({"project": "DEL"})
        self.assertIn("Blocked:\nDEL-3 is blocked by DEL-1", text)
        self.assertIn("Stuck:\n" + "x" * ga.Walk.RISK_PART_CHARS, text)
        self.assertNotIn("x" * (ga.Walk.RISK_PART_CHARS + 1), text)
        self.assertNotIn("GitHub", text)                 # no repository: nothing to say
        self.assertNotIn("without a ticket", text)       # a source that failed is left out
        self.assertIn("Open questions with the client", text)

    def test_nothing_recorded_says_so(self):
        walk = ga.Walk(CTX, "risks?")
        with patch.object(walk, "find_blocked", return_value=""), patch.object(walk, "find_stuck", return_value=""), \
                patch.object(walk, "jira_vs_github", return_value=""), \
                patch.object(walk, "uncovered_requirements", return_value=""), \
                patch.object(walk, "open_questions", return_value=""):
            self.assertEqual(walk.project_risks({}), "No risk facts are recorded for this project.")


class HelperSelectTests(unittest.TestCase):
    RESULT = "\n".join(["25 tickets:"] + [f"DEL-{n} | To Do | ticket about topic {n} " + "y" * 60 for n in range(25)])

    def test_off_unless_turned_on(self):
        walk = ga.Walk(CTX, "which tickets are about payments?")
        with patch.dict(os.environ, {"GRAPH_AGENT_HELPER": ""}), patch.object(llm_client, "complete") as call:
            self.assertEqual(walk._select(self.RESULT), self.RESULT)
        call.assert_not_called()

    def test_the_lines_kept_are_the_graphs_own_and_the_header_stays(self):
        walk = ga.Walk(CTX, "which tickets are about topic 3 and 7?")
        with patch.dict(os.environ, {"GRAPH_AGENT_HELPER": "1"}), \
                patch.object(llm_client, "complete", return_value='{"keep": [4, 8, 99]}'):
            kept = walk._select(self.RESULT).split("\n")
        self.assertEqual(kept, [self.RESULT.split("\n")[n] for n in (0, 4, 8)])

    def test_a_failure_or_nothing_kept_gives_the_result_as_it_was(self):
        walk = ga.Walk(CTX, "q")
        with patch.dict(os.environ, {"GRAPH_AGENT_HELPER": "1"}):
            with patch.object(llm_client, "complete", side_effect=llm_client.LLMUnavailable("busy")):
                self.assertEqual(walk._select(self.RESULT), self.RESULT)
            with patch.object(llm_client, "complete", return_value='{"keep": []}'):
                self.assertEqual(walk._select(self.RESULT), self.RESULT)
            with patch.object(llm_client, "complete", return_value="not json"):
                self.assertEqual(walk._select(self.RESULT), self.RESULT)

    def test_a_short_result_is_not_sent_to_the_helper(self):
        walk = ga.Walk(CTX, "q")
        with patch.dict(os.environ, {"GRAPH_AGENT_HELPER": "1"}), patch.object(llm_client, "complete") as call:
            self.assertEqual(walk._select("DEL-1 | Done"), "DEL-1 | Done")
        call.assert_not_called()

    def test_the_helper_is_a_small_model_without_the_big_fallback(self):
        with patch.dict(os.environ, {"MEETING_SELECT_PROVIDER": "", "MEETING_SELECT_MODEL": "", "SELECT_MODEL": "",
                                     "GROQ_FALLBACK_MODEL": "big"}):
            os.environ.pop("SELECT_MODEL")
            self.assertEqual(llm_client.settings("select"), ("groq", ["llama-3.1-8b-instant"]))


if __name__ == "__main__":
    unittest.main()


class MeetingPermissionTests(unittest.TestCase):
    """canReadApprovedMeetings: without it the chat's tools say meetings are not available."""

    def test_meeting_tools_refuse_without_the_permission(self):
        ctx = AccessContext("acme", ("DEL",), can_read_meetings=False)
        walk = ga.Walk(ctx, "what did the client ask about login?")
        for tool in (walk.open_questions, walk.requirement_history, walk.uncovered_requirements, walk.search_meetings):
            self.assertEqual(tool({}), ga.NO_MEETINGS)

    def test_knowledge_sources_still_answer_without_meetings(self):
        from syntrace_ai.meetings import meeting_notes
        from syntrace_ai.workers import knowledge_worker
        ctx = AccessContext("acme", ("DEL",), syntrace_projects=("p1",), can_read_meetings=False)
        walk = ga.Walk(ctx, "q")
        with patch.object(meeting_notes, "search_meetings") as meetings, \
                patch.object(knowledge_worker, "search", return_value=[], create=True):
            walk.search_meetings({"query": "login"})
        meetings.assert_not_called()

    def test_risks_leave_out_meetings_without_the_permission(self):
        walk = ga.Walk(AccessContext("acme", ("DEL",), can_read_meetings=False), "risks?")
        with patch.object(walk, "find_blocked", return_value="DEL-3 is blocked"), \
                patch.object(walk, "find_stuck", return_value=""), patch.object(walk, "jira_vs_github", return_value=""):
            text = walk.project_risks({})
        self.assertEqual(text, "Blocked:\nDEL-3 is blocked")


class RateWaitTests(unittest.TestCase):
    """A per-minute Groq limit is waited out once; the day's limit is not."""

    def error(self, text):
        return type("RateLimitError", (Exception,), {})(text)

    def test_short_and_long_waits(self):
        self.assertAlmostEqual(ga._short_wait(self.error("Please try again in 6.59s. Need more")), 7.09)
        self.assertIsNone(ga._short_wait(self.error("Please try again in 4m58.5s.")))
        self.assertIsNone(ga._short_wait(self.error("rate limit")))

    def test_the_same_model_is_asked_again_after_a_short_wait(self):
        message = type("M", (), {"tool_calls": None})()
        done = type("C", (), {"choices": [type("Ch", (), {"message": message})()], "usage": None})()
        calls = []

        def create(**kw):
            calls.append(kw["model"])
            if len(calls) == 1:
                raise self.error("try again in 0.1s")
            return done
        client = type("Cl", (), {})()
        client.chat = type("Ch", (), {"completions": type("Co", (), {"create": staticmethod(create)})()})()
        with patch.object(ga.ag, "_get_client", return_value=client), patch.object(ga.ag, "count_tokens"), \
                patch.object(ga.time, "sleep") as slept, patch.dict(os.environ, {"GROQ_FALLBACK_MODEL": "small"}):
            self.assertIs(ga._ask([{"role": "user", "content": "q"}], False), message)
        self.assertEqual(calls, [ga.ag.GROQ_MODEL, ga.ag.GROQ_MODEL])
        slept.assert_called_once()


class FitTests(unittest.TestCase):
    """A long tool result is cut at whole lines, and the model is told the rest exists."""

    def test_a_short_result_is_left_as_it_is(self):
        self.assertEqual(ga._fit("DEL-1 | Done", 100), "DEL-1 | Done")

    def test_lines_are_never_cut_in_the_middle_and_the_rest_is_counted(self):
        result = "\n".join(["80 tickets:"] + [f"DEL-{100 + n} | To Do | a ticket about item {n}" for n in range(80)])
        out = ga._fit(result, 600).split("\n")
        self.assertTrue(all(line in result.split("\n") for line in out[:-1]))   # whole lines only
        hidden = 81 - (len(out) - 1)
        self.assertIn(f"[{hidden} more lines not shown", out[-1])
        self.assertLessEqual(len("\n".join(out)), 600)

    def test_one_long_line_is_cut_at_a_word(self):
        out = ga._fit("word " * 300, 400)
        self.assertTrue(out.split("\n")[0].endswith("word ..."))
        self.assertIn("not shown", out)


class MyTasksTests(unittest.TestCase):
    """SYNT-918: "what did I finish, what is left" and "explain this task"."""

    ITEMS = [{"key": "DEL-1", "summary": "Login page", "status": "Done", "category": "done", "priority": "High",
              "due": None, "type": "Story", "url": None, "resolved": "2026-11-20", "updated": None, "active": True},
             {"key": "DEL-2", "summary": "Reports", "status": "To Do", "category": "new", "priority": "Low",
              "due": None, "type": "Story", "url": None, "resolved": None, "updated": None, "active": True},
             {"key": "DEL-3", "summary": "Payments", "status": "In Progress", "category": "indeterminate",
              "priority": "Medium", "due": "2026-11-30", "type": "Task", "url": None, "resolved": None,
              "updated": None, "active": True}]

    def walk(self, account="acc-1"):
        return ga.Walk(AccessContext("acme", ("DEL",), jira_account_id=account), "what is left for me?")

    def test_unknown_asker_is_told_not_guessed(self):
        self.assertIn("I don't know who is asking", self.walk(None).my_tasks({}))

    def test_progress_then_blocked_first(self):
        from syntrace_ai.assistant import insights
        from syntrace_ai.github import github_graph
        with patch.object(ga, "my_tasks", return_value={"me": "Fatma", "scope": "active", "items": self.ITEMS}), \
                patch.object(insights, "blockers", return_value={"items": [
                    {"key": "DEL-2", "blocked": True, "by": [{"key": "DEL-9", "done": False}]}]}), \
                patch.object(github_graph, "activity", return_value={"pull_requests": []}):
            text = self.walk().my_tasks({})
        lines = text.split("\n")
        self.assertEqual(lines[0], "Fatma: 1 of 3 tickets done (33%), in the active sprint.")
        self.assertTrue(lines[2].startswith("DEL-2 ") and "BLOCKED by DEL-9" in lines[2])   # blocked first
        self.assertTrue(lines[3].startswith("DEL-3 ") and "due 2026-11-30" in lines[3])
        self.assertIn("Done (1), latest first:\nDEL-1 | Done | Login page", text)

    def test_explain_gathers_every_source_and_skips_empty_ones(self):
        w = self.walk()
        with patch.object(w, "get_ticket", return_value="summary: Payments\ndescription: pay by card"), \
                patch.object(w, "get_links", return_value="DEL-3 is blocked by DEL-9"), \
                patch.object(w, "get_comments", return_value="No comments on DEL-3."), \
                patch.object(w, "_task_meeting", return_value='2026-11-05 Kickoff: [requirement] Pay by card (said: "بالفيزا")'), \
                patch.object(w, "code_progress", side_effect=RuntimeError("down")):
            text = w.explain_task({"key": "DEL-3"})
        self.assertIn("Ticket:\nsummary: Payments", text)
        self.assertIn("Client meeting:\n2026-11-05 Kickoff", text)
        self.assertNotIn("Latest comments", text)
        self.assertNotIn("Code so far", text)

    def test_explain_a_ticket_the_asker_cannot_see(self):
        w = self.walk()
        with patch.object(w, "get_ticket", return_value="No ticket DEL-404 in the allowed projects."):
            self.assertEqual(w.explain_task({"key": "DEL-404"}), "No ticket DEL-404 in the allowed projects.")


class ClarifyTests(unittest.TestCase):
    """The agent's question back comes with its choices apart, for buttons in the app."""

    def call(self, arguments):
        return type("Call", (), {"function": type("F", (), {"arguments": json.dumps(arguments)})()})()

    def test_question_and_choices(self):
        walk = ga.Walk(CTX, "what is blocked?")
        out = ga._clarify(self.call({"question": "BE or DEL?", "choices": ["BE", "DEL", "DEL"]}), walk, "q")
        self.assertEqual(out, {"status": "ok", "answer": "BE or DEL?", "links": [], "source": "clarify",
                               "choices": ["BE", "DEL"]})

    def test_a_ticket_no_tool_returned_is_not_offered(self):
        walk = ga.Walk(CTX, "q")
        walk.urls["DEL-1"] = None
        out = ga._clarify(self.call({"question": "Which one?", "choices": ["DEL-1", "DEL-99", "a", "b", "c", "d"]}),
                          walk, "q")
        self.assertEqual(out["choices"], ["DEL-1", "a", "b", "c"])

    def test_no_question_is_no_answer(self):
        self.assertIsNone(ga._clarify(self.call({"choices": ["x"]}), ga.Walk(CTX, "q"), "q"))

    def test_the_api_sends_the_choices(self):
        from fastapi.testclient import TestClient
        from syntrace_ai.api import ai_service
        with patch.dict(os.environ, {"AI_API_KEY": "clarify-key"}), \
                patch.object(ai_service, "_cached_answer", return_value={
                    "status": "ok", "answer": "BE or DEL?", "links": [], "source": "clarify", "choices": ["BE", "DEL"]}):
            r = TestClient(ai_service.app).post("/ask", headers={"X-Internal-Api-Key": "clarify-key"}, json={
                "question": "what is blocked?", "companyId": "acme", "employeeId": "u1", "allowedProjects": ["BE", "DEL"]})
        self.assertEqual(r.json()["choices"], ["BE", "DEL"])
        self.assertEqual(r.json()["source"], "clarify")
