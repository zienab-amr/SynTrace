import unittest
from unittest.mock import patch

import answer_generator as agent

import os
from fastapi.testclient import TestClient
import ai_service


class Recorder:
    def __init__(self):
        self.asked = []
        self.prompts = []

    def complete(self, prompt):
        self.prompts.append(prompt)
        return None

    def answer(self, question, context):
        self.asked.append(question)
        return {"status": "ok", "answer": "stub", "links": []}


class ChatContractTests:
    def setUp(self):
        self.client = TestClient(ai_service.app)

    def ask(self, recorder, data):
        with patch.dict(os.environ, {"AI_API_KEY": "test-key"}), \
             patch.object(ai_service, "_cached_answer", recorder.answer), \
             patch.object(agent, "_complete", recorder.complete):
            return self.client.post("/ask", json={
                "companyId": "test", "employeeId": "test",
                "allowedProjects": ["SYNTECH", "SYNT"], **data,
            }, headers={"X-Internal-Api-Key": "test-key"})



class MixedAssistantQuestionTests(unittest.TestCase):
    def test_ticket_not_found_does_not_skip_project_question(self):
        ticket = "مين خلص SYNTECH-5 وإمتى؟"
        count = "كام bug مفتوحة في SYNT؟"
        missing = {"status": "not_found", "answer": "Ticket unavailable", "links": []}
        counted = {"status": "ok", "answer": "3 open bugs", "links": []}
        with patch("intent.route", return_value=None), \
             patch.object(agent, "answer_key_question", return_value=[{"type": "no_key_found"}]) as lookup, \
             patch.object(agent, "_keyless_question_result", side_effect=[missing, counted]) as answer:
            result = agent._generate_answer_result(f"{ticket}\n{count}", object())

        lookup.assert_not_called()
        self.assertEqual([call.args[0] for call in answer.call_args_list], [ticket, count])
        self.assertIn("Ticket unavailable", result["answer"])
        self.assertIn("3 open bugs", result["answer"])

    def test_single_ticket_question_keeps_ticket_lookup(self):
        question = "Who closed SYNT-5?"
        context = object()
        with patch("intent.route", return_value=None), \
             patch.object(agent, "answer_key_question", return_value=[]) as lookup:
            agent._generate_answer_result(question, context)
        lookup.assert_called_once_with(question, context)


class AssistantFollowupTests(unittest.TestCase):
    def test_commits_after_multiple_tickets_asks_before_querying(self):
        case = ChatContractTests()
        case.setUp()
        recorder = Recorder()
        response = case.ask(recorder, {
            "question": "commits?",
            "history": [{"question": "Show my tickets",
                         "answer": "SYNTECH-18 and SYNTECH-42"}],
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["choices"], [
            "Commits for SYNTECH-18", "Commits for SYNTECH-42",
        ])
        self.assertEqual(recorder.asked, [])
        self.assertEqual(recorder.prompts, [])

    def test_commits_after_one_ticket_keeps_its_key(self):
        import conversation

        turns = conversation.from_history([
            ("Show SYNTECH-18", "It is an open ticket."),
            ("Thanks", "You're welcome."),
        ])
        self.assertEqual(conversation.standalone("commits?", turns),
                         "commits? (SYNTECH-18)")

    def test_lowercase_sprint_project_correction_keeps_the_intent(self):
        import conversation

        turns = conversation.from_history([
            ("summarize the current sprint in syntrace", "SYNDATA Sprint 5"),
        ])
        self.assertEqual(conversation.standalone("syntrace not syndata", turns),
                         "summarize the current sprint in syntrace")


    def test_product_question_does_not_reuse_a_ticket_from_history(self):
        case = ChatContractTests()
        case.setUp()
        recorder = Recorder()
        for question in (
            "tell me about syntrace", "Can you tell me about SynTrace?",
            "Give me an overview of SynTrace", "What does SynTrace do?",
            "كلمني عن SynTrace", "ممكن تشرحلي SynTrace؟",
        ):
            with self.subTest(question=question):
                response = case.ask(recorder, {
                    "question": question,
                    "history": [{"question": "Show SYNT-103",
                                 "answer": "SYNT-103 creates SynTraceDB."}],
                })
                self.assertEqual(response.status_code, 200)
                self.assertIn("GitHub", response.json()["answer"])
                self.assertNotIn("SYNT-103", response.json()["answer"])
        self.assertEqual(recorder.asked, [])
        self.assertEqual(recorder.prompts, [])

    def test_product_overview_does_not_consume_ticket_or_sprint_questions(self):
        from general import product_overview

        self.assertIsNone(product_overview("Tell me about SynTrace sprint 4"))
        self.assertIsNone(product_overview("Tell me about SYNT-103"))


    def test_followup_paraphrases_for_commits_and_corrections(self):
        import conversation

        tickets = conversation.from_history([("Show my tickets", "SYNT-18 and SYNT-42")])
        for question in ("Any commits for those?", "ابعتلي الكوميتس بتاعتهم", "وريني الكوميتات بتاعتهم"):
            with self.subTest(question=question):
                self.assertEqual(conversation.commit_followup_keys(question, tickets), ["SYNT-18", "SYNT-42"])
        self.assertEqual(conversation.commit_followup_keys("Any commits for SYNT-9?", tickets), [])

        original = "summarize the current sprint in syntrace"
        sprint = conversation.from_history([(original, "SYNDATA Sprint 5")])
        for question in ("I meant SynTrace, not SYNDATA", "SynTrace, not SYNDATA", "قصدي SynTrace مش SYNDATA"):
            with self.subTest(question=question):
                self.assertEqual(conversation.standalone(question, sprint), original)


    def test_identity_uses_profile_instead_of_the_name_in_chat_history(self):
        case = ChatContractTests()
        case.setUp()
        recorder = Recorder()
        for question in ("Who am I?", "Do you know my name?", "أنا مين؟", "اسمي إيه؟"):
            with self.subTest(question=question):
                response = case.ask(recorder, {
                    "question": question,
                    "employeeDisplayName": "Fatma Example",
                    "history": [{"question": "What did Sara do?", "answer": "Sara closed SYNT-20."}],
                })
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()["source"], "identity")
                self.assertIn("Fatma Example", response.json()["answer"])
                self.assertNotIn("Sara", response.json()["answer"])
        self.assertEqual(recorder.asked, [])
        self.assertEqual(recorder.prompts, [])

    def test_identity_with_no_profile_tells_the_user_it_is_unavailable(self):
        case = ChatContractTests()
        case.setUp()
        data = case.ask(Recorder(), {"question": "u know my name", "history": []}).json()
        self.assertEqual(data["source"], "identity")
        self.assertIn("unavailable", data["answer"])
