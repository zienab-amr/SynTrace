"""Zeinab's chat contract: history from the backend (an explicit [] means none), addedTo merged into one
question (a correction wins, an extra question is added), quotedExcerpts as context, and cancellation
that stops further model calls and never returns, saves or caches the cancelled answer."""
import os
import unittest
from unittest.mock import patch

os.environ["AI_API_KEY"] = "test-key"

from fastapi.testclient import TestClient

from syntrace_ai.api import ai_service
from syntrace_ai.assistant import answer_generator as ag
from syntrace_ai.assistant import cancel
from syntrace_ai.assistant import conversation

HEADERS = {"X-Internal-Api-Key": "test-key"}
BASE = {"companyId": "c1", "employeeId": "e1", "allowedProjects": ["SYNTECH"], "conversationId": "chat-1"}
OK = {"status": "ok", "answer": "It is In Progress.", "links": []}


class Recorder:
    """Stands in for the pipeline and the model: records the question that reached the pipeline and
    every prompt the chat steps sent."""
    def __init__(self, reply=None, result=OK):
        self.asked, self.prompts, self.reply, self.result = [], [], reply, result

    def answer(self, question, ctx):
        self.asked.append(question)
        return dict(self.result)

    def complete(self, prompt):
        self.prompts.append(prompt)
        return self.reply(prompt) if callable(self.reply) else self.reply


class ChatContractTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(ai_service.app)
        conversation.forget("c1", "e1", "chat-1")
        ai_service._answers.clear()

    def ask(self, rec, body, headers=HEADERS):
        with patch.object(ai_service, "generate_answer_result", rec.answer), patch.object(ag, "_complete", rec.complete):
            return self.client.post("/ask", json={**BASE, **body}, headers=headers)

    def test_explicit_empty_history_never_uses_the_process_memory(self):
        conversation.remember("c1", "e1", "chat-1", "What's the status of SYNTECH-1?", "In Progress.", [])
        rec = Recorder(reply="What are the subtasks of SYNTECH-1?")
        self.ask(rec, {"question": "What about its subtasks?", "history": []})
        self.assertEqual(rec.asked, ["What about its subtasks?"])   # no rewrite from an old chat
        self.assertEqual(rec.prompts, [])

    def test_sent_history_is_the_context_oldest_first_and_is_not_saved(self):
        rec = Recorder(reply="What are the subtasks of SYNTECH-1?")
        r = self.ask(rec, {"question": "What about its subtasks?", "history": [
            {"question": "Who owns SYNTECH-9?", "answer": "Sara."},
            {"question": "What's the status of SYNTECH-1?", "answer": "It's In Progress."}]})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(rec.asked, ["What are the subtasks of SYNTECH-1?"])
        prompt = rec.prompts[0]
        self.assertLess(prompt.index("SYNTECH-9"), prompt.index("SYNTECH-1?"))
        self.assertEqual(conversation.recent("c1", "e1", "chat-1"), [])

    def test_without_the_field_the_old_memory_still_works(self):
        conversation.remember("c1", "e1", "chat-1", "What's the status of SYNTECH-1?", "In Progress.", [])
        rec = Recorder(reply="What are the subtasks of SYNTECH-1?")
        self.ask(rec, {"question": "What about its subtasks?"})
        self.assertEqual(rec.asked, ["What are the subtasks of SYNTECH-1?"])

    def test_added_to_an_extra_question_is_merged_into_one(self):
        rec = Recorder(reply="What is the status of SYNTECH-1 and who is assigned to it?")
        r = self.ask(rec, {"question": "ومين عليها؟", "addedTo": ["What's the status of SYNTECH-1?"], "history": []})
        self.assertEqual(r.json()["status"], "ok")
        self.assertEqual(rec.asked, ["What is the status of SYNTECH-1 and who is assigned to it?"])
        self.assertIn("1. What's the status of SYNTECH-1?\n2. ومين عليها؟", rec.prompts[0])

    def test_added_to_a_correction_wins(self):
        rec = Recorder(reply="Status of SYNTECH-2")
        self.ask(rec, {"question": "قصدي SYNTECH-2", "addedTo": ["Status SYNTECH-1"], "history": []})
        self.assertEqual(rec.asked, ["Status of SYNTECH-2"])
        self.assertIn("corrects an earlier one wins", rec.prompts[0])

    def test_three_messages_keep_their_order(self):
        rec = Recorder(reply="merged")
        self.ask(rec, {"question": "third", "addedTo": ["first SYNTECH-1", "second"], "history": []})
        self.assertIn("1. first SYNTECH-1\n2. second\n3. third", rec.prompts[0])

    def test_quoted_excerpts_are_the_newest_context(self):
        rec = Recorder(reply="Who fixed the login bug in SYNTECH-7?")
        self.ask(rec, {"question": "مين صلح ده؟", "quotedExcerpts": ["SYNTECH-7: the login bug was fixed last week"],
                       "history": [{"question": "What happened this sprint?", "answer": "Many things."}]})
        self.assertEqual(rec.asked, ["Who fixed the login bug in SYNTECH-7?"])
        prompt = rec.prompts[0]
        self.assertIn(conversation.QUOTED_LABEL, prompt)
        self.assertGreater(prompt.index("the login bug"), prompt.index("Many things"))

    def test_quoted_excerpts_alone_without_history(self):
        rec = Recorder(reply="Who owns SYNTECH-7?")
        self.ask(rec, {"question": "who owns this?", "quotedExcerpts": ["SYNTECH-7 is blocked"], "history": []})
        self.assertEqual(rec.asked, ["Who owns SYNTECH-7?"])

    def test_a_quote_cannot_widen_access(self):
        seen = {}
        rec = Recorder(reply="Who owns OTHER-1?")

        def answer(question, ctx):
            seen["projects"] = ctx.allowed_projects
            return dict(OK)
        with patch.object(ai_service, "generate_answer_result", answer), patch.object(ag, "_complete", rec.complete):
            self.client.post("/ask", json={**BASE, "question": "who owns this?", "quotedExcerpts": ["OTHER-1 is late"],
                                           "history": []}, headers=HEADERS)
        self.assertEqual(seen["projects"], ("SYNTECH",))

    def test_too_many_or_too_long_excerpts_are_refused(self):
        rec = Recorder()
        self.assertEqual(self.ask(rec, {"question": "x?", "quotedExcerpts": ["a"] * 6}).status_code, 422)
        self.assertEqual(self.ask(rec, {"question": "x?", "quotedExcerpts": ["a" * 2001]}).status_code, 422)

    def test_cancelled_before_start_runs_nothing(self):
        cancel.cancel("corr-early")
        rec = Recorder(reply="merged")
        r = self.ask(rec, {"question": "ومين عليها؟", "addedTo": ["Status SYNTECH-1"]},
                     headers={**HEADERS, "X-Correlation-Id": "corr-early"})
        self.assertEqual(r.status_code, 409)
        self.assertEqual((rec.prompts, rec.asked), ([], []))

    def test_cancelled_while_answering_is_not_returned_saved_or_cached(self):
        os.environ["ASK_CACHE_SECONDS"] = "600"

        def answer(question, ctx):
            cancel.cancel("corr-mid")   # DELETE /ask/corr-mid arrives while the pipeline runs
            return dict(OK)
        with patch.object(ai_service, "generate_answer_result", answer), \
                patch.object(ai_service, "CACHE_SECONDS", 600), \
                patch.object(ai_service.cache_version, "token", lambda *a: "v1"):
            r = self.client.post("/ask", json={**BASE, "question": "Status SYNTECH-1?"},
                                 headers={**HEADERS, "X-Correlation-Id": "corr-mid"})
        self.assertEqual(r.status_code, 409)
        self.assertEqual(conversation.recent("c1", "e1", "chat-1"), [])
        self.assertEqual(len(ai_service._answers), 0)

    def test_cancel_stops_the_next_model_call(self):
        calls = []

        def merge_model(prompt):
            calls.append(prompt)
            cancel.cancel("corr-merge")   # cancelled right after the merge call
            return "merged SYNTECH-1"
        with patch.object(ai_service, "generate_answer_result", lambda q, c: dict(OK)):
            started = cancel.start("corr-merge", 60)
            try:
                conversation.merge(["Status SYNTECH-1", "and who?"], [], complete=merge_model)
                with self.assertRaises(cancel.Cancelled):
                    ag._complete("next prompt")   # the next model call stops before spending tokens
            finally:
                cancel.finish(started)
        self.assertEqual(len(calls), 1)

    def test_delete_uses_the_same_correlation_id(self):
        r = self.client.delete("/ask/corr-x", headers=HEADERS)
        self.assertIn(r.status_code, (200, 204))
        started = cancel.start("corr-x", 60)
        try:
            with self.assertRaises(cancel.Cancelled):
                cancel.check()
        finally:
            cancel.finish(started)

    def test_response_contract_is_unchanged(self):
        r = self.ask(Recorder(), {"question": "Status SYNTECH-1?", "history": []},
                     headers={**HEADERS, "X-Correlation-Id": "c-9"})
        # "choices" (buttons for a question back) is the one field added; it is [] on every other answer
        self.assertEqual(set(r.json()), {"status", "answer", "links", "correlationId", "source", "choices"})
        self.assertEqual(r.json()["choices"], [])


if __name__ == "__main__":
    unittest.main()
