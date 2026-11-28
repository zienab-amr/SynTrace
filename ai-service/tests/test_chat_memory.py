"""SYNT-912: the long-chat memory (CHAT_MEMORY=smart) against the default last-turns memory."""
import os
import unittest
from unittest.mock import patch

from syntrace_ai.assistant import conversation as cv


def turn(q, a, keys=()):
    return (0.0, q, a, list(keys))


CHAT = [turn("What are the open tickets in BE?", "BE has 37 open tickets, for example BE-12 and BE-40.", ["BE-12", "BE-40"]),
        turn("Which of them are bugs?", "9 of them are bugs, BE-12 among them.", ["BE-12"])] + \
       [turn(f"Question {n} about sprint {n}", f"Sprint {n} has {n + 3} tickets.") for n in range(3, 10)] + \
       [turn("What is DEL-5 about?", "DEL-5 is about the payment page.", ["DEL-5"])]


class DefaultMemoryTests(unittest.TestCase):
    def test_recent_is_the_last_turns_as_before(self):
        with patch.dict(os.environ, {"CHAT_MEMORY": "recent"}):
            text = cv.history_text("and its subtasks?", CHAT[-3:])
        self.assertEqual(text.count("Q: "), 3)
        self.assertNotIn("Older questions", text)


class SmartMemoryTests(unittest.TestCase):
    def setUp(self):
        env = patch.dict(os.environ, {"CHAT_MEMORY": "smart"})
        env.start()
        self.addCleanup(env.stop)

    def test_old_turns_are_digest_lines_and_the_latest_are_full(self):
        with patch.object(cv, "_related", return_value=[]):
            text = cv.history_text("going back to my first question, which were bugs?", CHAT)
        self.assertIn("- Q: What are the open tickets in BE? | tickets: BE-12, BE-40 | numbers: 37", text)
        self.assertIn("Latest turns:\nQ: Question 8 about sprint 8", text)
        self.assertIn("Q: What is DEL-5 about?\nA: DEL-5 is about the payment page.", text)
        self.assertLessEqual(len(text), cv.DIGEST_CHARS + 2000)

    def test_a_related_old_turn_comes_in_full(self):
        with patch.object(cv, "_related", return_value=[0]):
            text = cv.history_text("the open tickets you listed first", CHAT)
        self.assertIn("(earlier, about this question) Q: What are the open tickets in BE?\n"
                      "A: BE has 37 open tickets, for example BE-12 and BE-40.", text)
        self.assertNotIn("- Q: What are the open tickets in BE?", text)   # not twice

    def test_search_failure_keeps_the_digest(self):
        with patch("syntrace_ai.graph.embeddings.embed_texts", side_effect=RuntimeError("ollama down")):
            text = cv.history_text("first question?", CHAT)
        self.assertIn("- Q: What are the open tickets in BE?", text)

    def test_the_chat_is_kept_longer_and_answers_are_not_cut_at_400(self):
        cv.forget("acme", "u-mem", "c1")
        for n in range(12):
            cv.remember("acme", "u-mem", "c1", f"q{n}", "x" * 1000, [])
        kept = cv.recent("acme", "u-mem", "c1")
        self.assertEqual(len(kept), 12)
        self.assertEqual(len(kept[0][2]), 1000)
        cv.forget("acme", "u-mem", "c1")

    def test_a_long_chat_does_not_grow_the_prompt(self):
        long_chat = [turn(f"Question number {n} about something long " + "word " * 20, "answer " * 100)
                     for n in range(30)]
        with patch.object(cv, "_related", return_value=[]):
            self.assertLess(len(cv.history_text("q", long_chat)), 6000)


if __name__ == "__main__":
    unittest.main()


class RewriteGuardTests(unittest.TestCase):
    def test_a_rewrite_that_misspells_the_project_is_not_used(self):
        turns = [(0.0, "open tickets in DURACLOUD?", "DURACLOUD-39 and DURACLOUD-54.", ["DURACLOUD-39"])]
        out = cv.standalone("How many tickets does DURACLOUD have in total?", turns,
                            complete=lambda p: "How many tickets does DURANLOUD have in total?")
        self.assertEqual(out, "How many tickets does DURACLOUD have in total?")


class MyWorkRoutingTests(unittest.TestCase):
    def test_my_work_questions_are_recognised(self):
        from syntrace_ai.assistant import graph_agent as ga
        for q in ("What did I finish and what is left for me?", "my tasks", "where am I on login?",
                  "خلصت ايه من التاسكات؟", "فاضلي ايه؟", "اشرحلي التاسك DEL-3"):
            self.assertTrue(ga.MY_WORK.search(q), q)
        for q in ("How many open tickets does DEL have?", "what did the client finish?"):
            self.assertFalse(ga.MY_WORK.search(q), q)


class MyWorkDirectTests(unittest.TestCase):
    def test_progress_is_answered_from_the_graph_without_a_model(self):
        from syntrace_ai.assistant import answer_generator as ag
        from syntrace_ai.assistant import graph_agent as ga
        from syntrace_ai.graph.query_engine import AccessContext
        ctx = AccessContext("acme", ("DEL",), jira_account_id="acc-1")
        with patch.object(ga.Walk, "my_tasks", return_value="Fatma: 1 of 3 tickets done (33%), in the active sprint."), \
                patch.object(ag, "_complete") as model, patch.object(ag, "_agent_result") as agent:
            out = ag._keyless_question_result("What did I finish and what is left for me?", ctx)
        model.assert_not_called()
        agent.assert_not_called()
        self.assertIn("1 of 3", out["answer"])

    def test_explain_goes_to_the_agent(self):
        from syntrace_ai.assistant import answer_generator as ag
        from syntrace_ai.graph.query_engine import AccessContext
        ctx = AccessContext("acme", ("DEL",), jira_account_id="acc-1")
        with patch.object(ag, "_agent_result", return_value={"status": "ok", "answer": "steps", "links": []}) as agent:
            out = ag._keyless_question_result("explain my task DEL-3, what do I need to do?", ctx)
        agent.assert_called_once()
        self.assertEqual(out["answer"], "steps")
