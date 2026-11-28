"""The read-only insight tools, live: lab Neo4j (tenant "lab"), real Groq. Run by run_followup_test.ps1.

Each query runs once directly, so a Cypher error shows on its own, then one question goes through
/ask to check the planner sends it to the agent and the agent uses the tool. It only reads the graph.
"""
import os
import unittest

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.api import ai_service
from syntrace_ai.assistant import conversation
from syntrace_ai.assistant import graph_agent
from syntrace_ai.assistant import insights
from syntrace_ai.graph.query_engine import AccessContext, run_query

READY = os.getenv("NEO4J_INTEGRATION") == "1" and os.getenv("FOLLOWUP_TEST") == "1"
TENANT = "lab"


def busiest_project_and_sprint():
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $t})-[:IN_SPRINT]->(s:Sprint) "
        "RETURN w.project_key AS project, s.name AS sprint, count(*) AS n ORDER BY n DESC LIMIT 1", t=TENANT)
    if rows:
        return rows[0]["project"], rows[0]["sprint"]
    rows = run_query("MATCH (w:WorkItem {tenant_id: $t}) RETURN w.project_key AS p, count(*) AS n "
                     "ORDER BY n DESC LIMIT 1", t=TENANT)
    return rows[0]["p"], None


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1, FOLLOWUP_TEST=1 and the lab Neo4j")
class InsightsLiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.project, cls.sprint = busiest_project_and_sprint()
        cls.ctx = AccessContext(TENANT, (cls.project,))
        print(f"\nproject {cls.project}, sprint {cls.sprint}")

    def ask(self, question):
        os.environ.setdefault("AI_API_KEY", "test-key")
        ai_service.CACHE_SECONDS = 0
        conversation._memory.clear()
        graph_agent.TRACE.clear()
        request = ai_service.AskRequest(question=question, company_id=TENANT, employee_id="tester",
                                        allowed_projects=[self.project])
        response = ai_service.ask(request, x_internal_api_key=os.environ["AI_API_KEY"])
        tools = [t["tool"] for t in graph_agent.TRACE]
        print(f"\nQ: {question}\n  tools: {tools}\n  A [{response.status}]: {response.answer}")
        return response, tools

    def test_queries_run(self):
        ready = insights.readiness(self.ctx)
        stuck = insights.stuck(self.ctx, min_days=30)
        print(f"\nreadiness: {ready['total']} tickets, first {ready['items'][:2]}")
        print(f"stuck 30+ days: {stuck['total']}, first {stuck['items'][:2]}")
        if self.sprint:
            summary = insights.sprint_summary(self.ctx, self.sprint)
            print(f"sprint {summary['sprint']['name']}: {summary['counts']}, done {len(summary['done'])}, "
                  f"blocked {len(summary['blocked'])}")
            self.assertGreater(summary["total"], 0)
        uncovered = insights.uncovered_requirements(self.ctx)
        print(f"uncovered meeting items: {uncovered['total']}")

    def test_readiness_question(self):
        answer, tools = self.ask(f"Which open tickets in {self.project} are missing a description or an assignee?")
        self.assertEqual(answer.status, "ok")
        self.assertIn("check_readiness", tools)

    def test_stuck_question_arabic(self):
        answer, tools = self.ask(f"ايه التذاكر اللي واقفة بقالها كتير في {self.project}؟")
        self.assertIn("find_stuck", tools)

    def test_sprint_summary(self):
        if not self.sprint:
            self.skipTest("the lab graph has no sprints")
        answer, tools = self.ask(f"Summarize the sprint {self.sprint}")
        self.assertEqual(answer.status, "ok")
        self.assertIn("summarize_sprint", tools)


if __name__ == "__main__":
    unittest.main()
