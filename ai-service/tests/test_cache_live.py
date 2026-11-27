"""The answer cache, live: lab Neo4j (tenant "lab"), real Groq. Run by run_followup_test.ps1.

The same question twice is answered once; after the company's cache token changes (what the consumer
does on every Jira change) the question is answered again. It writes one CacheVersion node for "lab".
"""
import os
import unittest

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.api import ai_service
from syntrace_ai.assistant import cache_version
from syntrace_ai.assistant import conversation
from syntrace_ai.graph import query_engine
from syntrace_ai.graph.query_engine import run_query

READY = os.getenv("NEO4J_INTEGRATION") == "1" and os.getenv("FOLLOWUP_TEST") == "1"
TENANT = "lab"


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1, FOLLOWUP_TEST=1 and the lab Neo4j")
class CacheLiveTests(unittest.TestCase):
    def test_answer_is_reused_until_data_changes(self):
        row = run_query("MATCH (w:WorkItem {tenant_id: $t}) WHERE w.summary IS NOT NULL "
                        "RETURN w.key AS key, w.project_key AS project ORDER BY w.key LIMIT 1", t=TENANT)[0]
        os.environ.setdefault("AI_API_KEY", "test-key")
        ai_service.CACHE_SECONDS = 3600
        ai_service._answers.clear()
        conversation._memory.clear()
        calls = []
        real = ai_service.generate_answer_result

        def counted(question, ctx):
            calls.append(question)
            return real(question, ctx)

        ai_service.generate_answer_result = counted
        try:
            def ask():
                request = ai_service.AskRequest(question=f"What is the status of {row['key']}?", company_id=TENANT,
                                                employee_id="tester", allowed_projects=[row["project"]])
                return ai_service.ask(request, x_internal_api_key=os.environ["AI_API_KEY"])

            first = ask()
            second = ask()
            print(f"\n{row['key']}: {first.answer}\ncalls after two questions: {len(calls)}")
            self.assertEqual(first.status, "ok")
            self.assertEqual(len(calls), 1, "the second identical question must come from the cache")
            self.assertEqual(first.answer, second.answer)

            cache_version.bump(TENANT, lambda: query_engine.get_driver().session())
            ask()
            print(f"calls after the data changed: {len(calls)}")
            self.assertEqual(len(calls), 2, "after a change the question must be answered again")
        finally:
            ai_service.generate_answer_result = real


if __name__ == "__main__":
    unittest.main()
