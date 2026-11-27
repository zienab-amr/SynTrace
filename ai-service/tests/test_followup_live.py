"""Follow-up questions and "who finished it" questions, live: lab Neo4j (tenant "lab"), real Groq.

  run by run_followup_test.ps1 with FOLLOWUP_TEST=1

It goes through the /ask handler itself, so the chat memory, the rewrite and the agent are all used.
It only reads the graph. It prints every question and answer.
"""
import os
import unittest

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.api import ai_service
from syntrace_ai.assistant import conversation
from syntrace_ai.graph.query_engine import run_query

READY = os.getenv("NEO4J_INTEGRATION") == "1" and os.getenv("FOLLOWUP_TEST") == "1"
TENANT = "lab"
KEY = "test-key"


def parent_with_subtasks():
    rows = run_query(
        "MATCH (c:WorkItem {tenant_id: $t})-[:CHILD_OF]->(p:WorkItem {tenant_id: $t}) "
        "WHERE p.project_key = c.project_key "
        "WITH p, collect(c.key) AS children WHERE size(children) >= 2 AND size(children) <= 8 "
        "RETURN p.key AS key, p.project_key AS project, children ORDER BY size(children) DESC, p.key LIMIT 1",
        t=TENANT)
    return rows[0] if rows else None


def finished_then_reassigned():
    """A ticket moved to a done status by one person and reassigned later by someone else."""
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $t})-[:HAD_CHANGE]->(s:ChangeEvent) "
        "WHERE toLower(s.field) = 'status' AND toLower(s.to_name) IN ['done', 'closed', 'resolved'] "
        "AND s.author IS NOT NULL "
        "MATCH (w)-[:HAD_CHANGE]->(a:ChangeEvent) "
        "WHERE toLower(a.field) = 'assignee' AND a.changed_at > s.changed_at AND a.to_name IS NOT NULL "
        "AND a.to_name <> s.author "
        "RETURN w.key AS key, w.project_key AS project, s.author AS finisher, a.to_name AS later "
        "ORDER BY w.key LIMIT 1", t=TENANT)
    return rows[0] if rows else None


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1, FOLLOWUP_TEST=1 and the lab Neo4j")
class FollowUpLiveTests(unittest.TestCase):
    def setUp(self):
        os.environ.setdefault("AI_API_KEY", KEY)
        ai_service.CACHE_SECONDS = 0
        conversation._memory.clear()

    def ask(self, question, project, chat):
        request = ai_service.AskRequest(question=question, company_id=TENANT, employee_id="tester",
                                        allowed_projects=[project], conversation_id=chat)
        response = ai_service.ask(request, x_internal_api_key=os.environ["AI_API_KEY"])
        asked = conversation.recent(TENANT, "tester", chat)
        print(f"\n[{chat}] Q: {question}\n  read as: {asked[-1][1] if asked else '(not remembered)'}"
              f"\n  A [{response.status}]: {response.answer}")
        return response

    def test_subtasks_follow_up_english_and_arabic(self):
        parent = parent_with_subtasks()
        self.assertIsNotNone(parent, "the lab graph has no ticket with subtasks")
        print(f"\nparent {parent['key']} children {parent['children']}")
        for chat, first, follow in (
                ("en", f"What is the status of {parent['key']}?", "And what are its subtasks?"),
                ("ar", f"ايه الـ status بتاعة {parent['key']}؟", "طب الـ subtasks بتاعتها ايه؟")):
            self.assertEqual(self.ask(first, parent["project"], chat).status, "ok")
            answer = self.ask(follow, parent["project"], chat)
            self.assertEqual(answer.status, "ok")
            named = [k for k in parent["children"] if k in answer.answer]
            self.assertTrue(named, f"no subtask of {parent['key']} named in the follow-up answer")

    def test_follow_up_in_a_new_chat_is_not_mixed(self):
        parent = parent_with_subtasks()
        self.ask(f"What is the status of {parent['key']}?", parent["project"], "chat-1")
        self.ask("And what are its subtasks?", parent["project"], "chat-2")
        self.assertEqual(len(conversation.recent(TENANT, "tester", "chat-1")), 1)
        rewritten = [t[1] for t in conversation.recent(TENANT, "tester", "chat-2")]
        self.assertFalse(any(parent["key"] in q for q in rewritten), "chat-2 used chat-1's ticket")

    def test_who_finished_a_reassigned_ticket(self):
        case = finished_then_reassigned()
        if not case:
            self.skipTest("no ticket in the lab graph was reassigned after it was finished")
        print(f"\n{case['key']}: finished by {case['finisher']}, later assigned to {case['later']}")
        answer = self.ask(f"Who finished {case['key']}?", case["project"], "who")
        self.assertEqual(answer.status, "ok")
        self.assertIn(case["finisher"], answer.answer)
        arabic = self.ask(f"مين اللي خلص {case['key']}؟", case["project"], "who-ar")
        self.assertIn(case["finisher"], arabic.answer)


if __name__ == "__main__":
    unittest.main()
