"""Offline tests for the HTTP service and the consumer's decisions.
RabbitMQ round trip (opt-in): RABBITMQ_INTEGRATION=1 with a local broker."""
import json
import os
import time
import sys
import types
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import patch

os.environ["AI_API_KEY"] = "test-key"
os.environ["ASK_CACHE_SECONDS"] = "0"

from fastapi.testclient import TestClient

import ai_consumer as ac
import ai_service
import answer_generator as ag
import ingest
import phase3_fakes as pf

T, CLOUD = "company-1", "cloud-1"
HEADERS = {"X-Internal-Api-Key": "test-key"}
BODY = {"question": "Who owns FIX-1?", "companyId": T, "employeeId": "e1", "allowedProjects": ["fix"]}


def issue(key="FIX-1", jid="100", updated="2026-10-27T11:00:00.000+0000"):
    return {"id": jid, "key": key, "self": f"https://api.atlassian.com/ex/jira/{CLOUD}/rest/api/3/issue/{jid}",
            "fields": {"summary": "s", "updated": updated, "project": {"id": "9", "key": "FIX"},
                       "issuetype": {"name": "Task"}}}


def message(kind="IssueUpdated", **extra):
    return json.dumps({"eventId": uuid.uuid4().hex, "eventType": kind, "schemaVersion": 2, "companyId": T,
                       "cloudId": CLOUD, "siteUrl": "https://company.atlassian.net", **extra}).encode()


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(ai_service.app)

    def post(self, result=None, error=None, headers=HEADERS, body=BODY):
        seen = {}

        def fake(question, ctx):
            seen["ctx"] = ctx
            if error:
                raise error
            return result

        with patch.object(ai_service, "generate_answer_result", fake):
            return self.client.post("/ask", json=body, headers=headers), seen

    def test_success_uses_camel_case_and_the_given_scope(self):
        r, seen = self.post({"status": "ok", "answer": "a", "links": [{"key": "FIX-1", "url": "u"}]},
                            headers={**HEADERS, "X-Correlation-Id": "c1"})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json(), {"status": "ok", "answer": "a", "links": [{"key": "FIX-1", "url": "u"}],
                                    "correlationId": "c1", "source": "ticket"})
        self.assertEqual((seen["ctx"].tenant_id, seen["ctx"].allowed_projects), (T, ("FIX",)))

    def test_wrong_or_missing_key_is_rejected(self):
        self.assertEqual(self.post(headers={})[0].status_code, 401)
        self.assertEqual(self.post(headers={"X-Internal-Api-Key": "no"})[0].status_code, 401)

    def test_missing_server_key_fails_closed(self):
        with patch.dict(os.environ, {"AI_API_KEY": ""}):
            self.assertEqual(self.post()[0].status_code, 503)

    def test_bad_body_is_rejected(self):
        self.assertEqual(self.post(body={**BODY, "question": "x" * 2001})[0].status_code, 422)
        self.assertEqual(self.post(body={**BODY, "question": "   "})[0].status_code, 400)

    def test_failures_are_503_and_hide_details(self):
        r, _ = self.post(error=RuntimeError("secret detail"))
        self.assertEqual(r.status_code, 503)
        self.assertNotIn("secret", r.text)
        self.assertEqual(self.post({"status": "search_unavailable", "answer": "x", "links": []})[0].status_code, 503)

    def test_docs_are_not_published(self):
        self.assertEqual(self.client.get("/docs").status_code, 404)


class StructuredAnswerTests(unittest.TestCase):
    CTX = SimpleNamespace(tenant_id=T, allowed_projects=("FIX",))

    def test_not_found_is_in_the_language_of_the_question(self):
        with patch.object(ag, "answer_key_question", lambda q, c: [{"type": "not_found", "key": "FIX-9", "message": "No ticket found with key FIX-9."}]):
            self.assertEqual(ag.generate_answer_result("What about FIX-9?", self.CTX),
                             {"status": "not_found", "answer": "No ticket found with key FIX-9.", "links": []})
            arabic = ag.generate_answer_result("حالة FIX-9؟", self.CTX)
        self.assertEqual(arabic["status"], "not_found")
        self.assertIn("FIX-9", arabic["answer"])
        self.assertNotIn("No ticket", arabic["answer"])


class ConsoleTests(unittest.TestCase):
    def test_legacy_console_encoding_cannot_fail_an_event(self):
        import subprocess
        import sys
        env = {**os.environ, "PYTHONUTF8": "0", "PYTHONIOENCODING": "cp1252"}
        code = "import webhook_handler; print('\\u2713 \\u26a0 ok')"
        done = subprocess.run([sys.executable, "-c", code], env=env, capture_output=True,
                              cwd=os.path.dirname(os.path.abspath(__file__)))
        self.assertEqual(done.returncode, 0, done.stderr[-300:])


class AggregateTests(unittest.TestCase):
    CTX = None

    def setUp(self):
        import query_engine
        self.CTX = query_engine.AccessContext("t", ("AAA", "BBB"))

    def test_planner_output_is_validated(self):
        import analytics
        self.assertIsNone(analytics.parse_plan("not json"))
        self.assertIsNone(analytics.parse_plan('{"kind":"aggregate","group_by":"x) DETACH DELETE w"}'))
        self.assertIsNone(analytics.parse_plan('{"kind":"aggregate","status_category":"nope"}'))
        self.assertEqual(analytics.parse_plan('<think>{"a"}</think>{"kind":"search","search_text":"login"}'),
                         {"kind": "search", "search_text": "login"})
        self.assertIsNone(analytics.parse_plan('{"kind":"search","search_text":5}')["search_text"])
        plan = analytics.parse_plan('{"kind":"aggregate","project":"aaa","status_category":"open"}')
        self.assertEqual((plan["project"], plan["status_category"]), ("AAA", "open"))

    def _run(self, plan_json, answers):
        import analytics
        calls = []

        def fake(query, **params):
            calls.append((query, params))
            return answers.pop(0)
        with patch.object(analytics, "run_query", fake):
            return analytics.run_plan(analytics.parse_plan(plan_json), self.CTX), calls

    def test_values_are_parameters_and_scope_is_always_applied(self):
        evil = "x' OR 1=1 //"
        result, calls = self._run(
            '{"kind":"aggregate","assignee":"%s","project":"AAA"}' % evil, [[{"total": 3}]])
        query, params = calls[0]
        self.assertEqual(result["total"], 3)
        self.assertNotIn(evil, query)
        self.assertEqual(params["assignee"], evil)
        self.assertEqual((params["tenant"], params["allowed"]), ("t", ["AAA"]))

    def test_project_outside_scope_never_reaches_the_graph(self):
        result, calls = self._run('{"kind":"aggregate","project":"SECRET"}', [])
        self.assertEqual((result["total"], calls), (0, []))

    def test_answer_numbers_come_from_the_graph_including_ties(self):
        import analytics
        plan = analytics.parse_plan('{"kind":"aggregate","group_by":"assignee"}')
        groups = [{"name": "A", "count": 5}, {"name": "B", "count": 5}, {"name": "C", "count": 1}]
        text = analytics.format_answer(plan, {"total": 11, "groups": groups, "tickets": [],
                                              "any_due_date": True}, False)
        self.assertIn("Number of tickets: 11.", text)
        self.assertIn("Most: A and B (5).", text)

    def test_no_due_dates_is_not_reported_as_all_on_time(self):
        import analytics
        plan = analytics.parse_plan('{"kind":"aggregate","overdue":true}')
        text = analytics.format_answer(plan, {"total": 0, "groups": [], "tickets": [],
                                              "any_due_date": False}, True)
        self.assertIn("معاد تسليم", text)

    def test_keyless_routing(self):
        import answer_generator as ag
        with patch.object(ag, "answer_key_question", lambda q, c: [{"type": "no_key_found"}]), \
                patch.object(ag, "_open_question_result", lambda q, c, s=None: {"status": "searched"}):
            with patch.object(ag, "_complete", lambda p: None):
                self.assertEqual(ag.generate_answer_result("x", self.CTX)["status"], "searched")
            with patch.object(ag, "_complete", lambda p: '{"kind":"out_of_scope"}'):
                self.assertEqual(ag.generate_answer_result("x", self.CTX)["status"], "no_results")
            with patch.object(ag, "_complete", lambda p: '{"kind":"aggregate"}'), \
                    patch.object(ag.analytics, "run_query", lambda q, **k: [{"total": 9}]):
                result = ag.generate_answer_result("كام تذكرة؟", self.CTX)
                self.assertEqual(result["status"], "ok")
                self.assertIn("9", result["answer"])

    def test_arabic_question_rejects_an_english_llm_answer(self):
        import answer_generator as ag
        self.assertFalse(ag._accepted("The assignee of AAA-1 is Sara.", ["AAA-1"], "مين ماسك AAA-1؟"))
        self.assertTrue(ag._accepted("AAA-1 ماسكها Sara.", ["AAA-1"], "مين ماسك AAA-1؟"))


class EvaluatorTests(unittest.TestCase):
    def test_connected_accepts_real_links_but_not_invented_ones(self):
        import evaluate_graphrag as ev
        case = {"cat": "related", "key": "A-1", "expect": {"A-2"}, "allowed": {"A-2", "A-3"}}
        self.assertTrue(ev.grade_text(case, "A-1 is related to A-2 and blocks A-3.")[0])
        self.assertFalse(ev.grade_text(case, "A-1 blocks A-3.")[0])
        self.assertFalse(ev.grade_text(case, "A-1 is related to A-2 and A-9.")[0])

    def test_failed_llm_calls_are_counted(self):
        import evaluate_graphrag as ev
        counter = ev.LlmFailureCounter()
        logger = __import__("logging").getLogger("test.evaluator")
        logger.propagate = False
        logger.addHandler(counter)
        logger.warning("LLM call failed: %s", "RateLimitError")
        logger.warning("something else")
        self.assertEqual(counter.count, 1)


class Catalog:
    def __init__(self):
        self.saved = []

    def get(self, *_):
        return {}

    def save(self, tenant, site, fields):
        self.saved.append((tenant, site, fields))

    def forget(self, tenant):
        self.saved.append(("forgot", tenant))


class ProcessorTests(unittest.TestCase):
    def setUp(self):
        self.tx = pf.GraphTx()
        self.catalog = Catalog()
        self.p = ac.EventProcessor(pf.session_factory(self.tx), self.catalog)

    def test_webhook_goes_through_the_native_handler_with_tenant_site_and_link_base(self):
        raw = {"webhookEvent": "jira:issue_created", "timestamp": 1788000000000, "issue": issue()}
        self.assertEqual(self.p.process(message(rawWebhook=raw)).action, "ack")
        node = self.tx.by_key("FIX-1")[0]
        self.assertEqual(node["tenant_id"], T)
        self.assertEqual(node["jira_site_id"], CLOUD)
        self.assertEqual(node["url"], "https://company.atlassian.net/browse/FIX-1")

    def test_snapshot_is_stored_then_a_delete_removes_it_and_a_new_snapshot_restores_it(self):
        self.assertEqual(self.p.process(message("IssueSnapshot", payload=issue())).action, "ack")
        self.assertTrue(self.tx.by_key("FIX-1"))
        raw = {"webhookEvent": "jira:issue_deleted", "timestamp": 1788000000000, "issue": issue()}
        self.assertEqual(self.p.process(message("IssueDeleted", rawWebhook=raw)).action, "ack")
        self.assertFalse(self.tx.by_key("FIX-1"))
        self.assertEqual(self.p.process(message("IssueSnapshot", payload=issue())).action, "ack")
        self.assertTrue(self.tx.by_key("FIX-1"))

    def test_same_key_in_two_companies_does_not_collide(self):
        self.p.process(message("IssueSnapshot", payload=issue()))
        other = json.loads(message("IssueSnapshot", payload=issue()))
        other["companyId"] = "company-2"
        self.p.process(json.dumps(other).encode())
        self.assertEqual(sorted(n["tenant_id"] for n in self.tx.by_key("FIX-1")), [T, "company-2"])

    def test_unusable_messages_go_to_dead_letter(self):
        self.assertEqual(self.p.process(b"{nope").action, "dead")
        self.assertEqual(self.p.process(json.dumps({"eventType": "IssueUpdated"}).encode()).action, "dead")
        self.assertEqual(self.p.process(message(cloudId=None)).action, "dead")
        self.assertEqual(self.p.process(message()).action, "dead")
        self.assertEqual(self.p.process(message("IssueSnapshot", payload={"x": 1})).action, "dead")
        self.assertEqual(self.p.process(message("FieldCatalog", payload={})).action, "dead")

    def test_unknown_jira_events_are_acked_not_parked(self):
        raw = {"webhookEvent": "jira:version_released", "timestamp": 1, "version": {"id": "1"}}
        self.assertEqual(self.p.process(message("VersionReleased", rawWebhook=raw)).action, "ack")

    def test_catalog_and_import_completed(self):
        embedded = []
        p = ac.EventProcessor(pf.session_factory(self.tx), self.catalog, embed=embedded.append)
        self.assertEqual(p.process(message("FieldCatalog", payload={"fields": [{"id": "x"}]})).action, "ack")
        self.assertEqual(self.catalog.saved[0][:2], (T, CLOUD))
        self.assertEqual(p.process(message("ImportCompleted", payload={"issueCount": 1})).action, "ack")
        self.assertEqual(embedded, [T])

    def test_import_end_does_not_wait_for_embeddings(self):
        requested = []
        p = ac.EventProcessor(pf.session_factory(self.tx), self.catalog, embed=requested.append)
        self.assertEqual(p.process(message("ImportCompleted")).action, "ack")
        self.assertEqual(requested, [T])

    def test_embedding_failure_is_kept_for_the_next_pass_and_other_tenants_continue(self):
        done, attempts = [], []

        def embed(tenant):
            attempts.append(tenant)
            if tenant == "bad" and attempts.count("bad") == 1:
                raise RuntimeError("ollama down")
            done.append(tenant)
        pending = lambda: [t for t in ("bad", "good") if t not in done]
        worker = ac.EmbeddingWorker(embed=embed, find_pending=pending, interval=1)
        worker.run_pass()
        self.assertEqual(done, ["good"])
        worker.run_pass()
        self.assertEqual(done, ["good", "bad"])

    def test_embedding_worker_survives_a_graph_failure(self):
        def down():
            raise RuntimeError("neo4j down")
        ac.EmbeddingWorker(embed=None, find_pending=down, interval=1).run_pass()

    def test_without_llm_only_strong_matches_are_shown_and_rewrite_is_used(self):
        import answer_generator as ag
        weak = {"key": "AAA-1", "summary": "Noise", "status": "To Do", "assignee": "S", "score": 0.38}
        strong = {"key": "AAA-2", "summary": "Login", "status": "To Do", "assignee": "S", "score": 0.5}
        asked = []

        def search(text, ctx):
            asked.append(text)
            return asked_hits
        fake = types.SimpleNamespace(semantic_search=search)
        with patch.dict(sys.modules, {"semantic_search": fake}), \
                patch.object(ag, "call_llm", lambda *a, **k: None):
            asked_hits = [weak]
            self.assertEqual(ag._open_question_result("q", None)["status"], "no_results")
            asked_hits = [strong, weak]
            result = ag._open_question_result("سؤال", None, "login")
        self.assertEqual(asked[-1], "login")
        self.assertIn("AAA-2", result["answer"])
        self.assertNotIn("AAA-1", result["answer"])

    def test_rate_limit_moves_to_the_fallback_model(self):
        import answer_generator as ag
        used = []

        class RateLimitError(Exception):
            pass

        def create(model, **_):
            used.append(model)
            if model == "main":
                raise RateLimitError()
            return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content="OK"))])
        client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create)))
        with patch.object(ag, "_get_client", lambda: client), patch.object(ag, "GROQ_MODEL", "main"), \
                patch.dict(os.environ, {"GROQ_FALLBACK_MODEL": "backup"}):
            self.assertEqual(ag._complete("p"), "OK")
        self.assertEqual(used, ["main", "backup"])

    def test_search_results_say_so_when_the_llm_is_down(self):
        import answer_generator as ag
        hit = {"key": "AAA-2", "summary": "Login", "status": "To Do", "assignee": "S", "score": 0.5}
        fake = types.SimpleNamespace(semantic_search=lambda q, c: [hit])
        with patch.dict(sys.modules, {"semantic_search": fake}), \
                patch.object(ag, "call_llm", lambda *a, **k: None):
            self.assertIn("unavailable", ag._open_question_result("how many?", None)["answer"])

    def test_custom_fields_keep_useful_values_and_hide_internal_ones(self):
        import query_engine as qe
        fields = {"Story point estimate": 5.0, "Rank": "0|i003", "Team": ["A", "B"], "Empty": None,
                  "Notes": "x" * 500, "Blob": {"a": 1}}
        defs = {"customfield_1": {"name": "Rank", "kind": "rank"}}
        self.assertEqual(qe.readable_custom_fields(json.dumps(fields), json.dumps(defs)),
                         {"Story point estimate": 5.0, "Team": "A, B"})
        self.assertEqual(qe.readable_custom_fields("not json", None), {})

    def test_custom_fields_reach_the_llm_and_a_value_is_grounded(self):
        import answer_generator as ag
        card = {"key": "AAA-1", "custom_fields": {"Story point estimate": 5.0}}
        self.assertIn("Story point estimate: 5.0", ag.build_ticket_context(card))
        self.assertIn(5.0, ag.ticket_facts(card))

    def test_out_of_scope_says_so_in_the_question_language(self):
        import answer_generator as ag
        import query_engine as qe
        ctx = qe.AccessContext("t", ("AAA",))
        with patch.object(ag, "answer_key_question", lambda q, c: [{"type": "no_key_found"}]), \
                patch.object(ag, "_complete", lambda p: '{"kind":"out_of_scope"}'):
            self.assertIn("برا بيانات", ag.generate_answer_result("الجو؟", ctx)["answer"])
            self.assertIn("jira ticket key", ag.generate_answer_result("weather?", ctx)["answer"].lower())

    def _plan(self, text):
        import analytics
        return analytics.parse_plan(text)

    def test_new_plan_fields_are_validated(self):
        self.assertIsNone(self._plan('{"kind":"aggregate","metric":"drop"}'))
        self.assertIsNone(self._plan('{"kind":"aggregate","since_days":"7 OR 1=1"}'))
        self.assertIsNone(self._plan('{"kind":"aggregate","since_days":0}'))
        self.assertIsNone(self._plan('{"kind":"aggregate","date_field":"x"}'))
        self.assertEqual(self._plan('{"kind":"aggregate","since_days":7}')["since_days"], 7)

    def _execute(self, plan_json, answers):
        import analytics
        import query_engine as qe
        calls = []

        def fake(query, **params):
            calls.append((query, params))
            return answers.pop(0)
        ctx = qe.AccessContext("t", ("AAA",))
        with patch.object(analytics, "run_query", fake):
            return analytics.run_plan(self._plan(plan_json), ctx), calls

    def test_time_logged_is_summed_by_the_graph_and_scoped(self):
        import analytics
        result, calls = self._execute('{"kind":"aggregate","metric":"time_logged","group_by":"assignee"}',
                                      [[{"seconds": 7200, "n": 2}], [{"name": "Sara", "n": 7200}]])
        self.assertTrue(all("w.project_key IN $allowed" in q and p["tenant"] == "t" for q, p in calls))
        text = analytics.format_answer(self._plan('{"kind":"aggregate","metric":"time_logged"}'), result, False)
        self.assertIn("2h", text)
        self.assertIn("Sara: 2h", text)

    def test_comment_and_change_lists_are_scoped_and_values_are_parameters(self):
        import analytics
        evil = "x' OR 1=1"
        plan = '{"kind":"aggregate","metric":"comments","text":"%s","assignee":"Sara"}' % evil
        record = {"key": "AAA-1", "url": "u", "at": "2026-11-01T10:00", "who": "Sara", "text": "hello"}
        result, calls = self._execute(plan, [[{"n": 1}], [record]])
        self.assertTrue(all(evil not in q and "$allowed" in q for q, _ in calls))
        self.assertIn("AAA-1 (2026-11-01, Sara): hello", analytics.format_answer(self._plan(plan), result, False))
        change = {"key": "AAA-1", "url": "u", "at": "2026-11-01", "who": "Sara", "field": "status",
                  "old": "To Do", "new": "Done"}
        plan = '{"kind":"aggregate","metric":"changes","change_field":"status","since_days":7}'
        result, calls = self._execute(plan, [[{"n": 1}], [change]])
        self.assertEqual(calls[0][1]["change_field"], "status")
        self.assertIn("status: To Do -> Done", analytics.format_answer(self._plan(plan), result, False))

    def test_outside_project_returns_nothing_for_every_metric(self):
        for metric in ("tickets", "time_logged", "comments", "changes"):
            result, calls = self._execute('{"kind":"aggregate","metric":"%s","project":"SECRET"}' % metric, [])
            self.assertEqual((result["total"], calls), (0, []))

    def test_ticket_filters_go_through_parameters(self):
        plan = '{"kind":"aggregate","label":"a","component":"b","parent":"c","reporter":"d","text":"e","since_days":3}'
        result, calls = self._execute(plan, [[{"total": 2}]])
        query, params = calls[0]
        self.assertEqual(result["total"], 2)
        for name, value in (("label", "a"), ("component", "b"), ("parent", "c"), ("reporter", "d"), ("text", "e")):
            self.assertEqual(params[name], value)
            self.assertIn(f"${name}", query)

    def test_full_ticket_details_reach_the_llm_within_a_budget(self):
        import answer_generator as ag
        card = {"key": "AAA-1", "reporter": "Omar", "labels": ["api"], "components": ["Core"],
                "changes": [{"at": "2026-11-01", "field": "status", "from": "To Do", "to": "Done", "by": "Sara"}]}
        context = ag.build_ticket_context(card)
        for piece in ("Reporter: Omar", "Labels: api", "Components: Core", "status: To Do -> Done (by Sara)"):
            self.assertIn(piece, context)
        self.assertIn("Sara", ag.ticket_facts(card))

    def test_question_without_a_key_gets_full_details_of_the_closest_tickets(self):
        import answer_generator as ag
        hits = [{"key": f"AAA-{i}", "summary": f"T{i}", "status": "To Do", "assignee": "S", "score": 0.6}
                for i in range(1, 6)]
        fake = types.SimpleNamespace(semantic_search=lambda q, c: hits)
        seen, contexts = [], []

        def details(card, ctx):
            seen.append(card["key"])
            return {"key": card["key"], "summary": "Login", "assignee": "Sara", "reporter": "Omar"}, {}

        def llm(question, context, style="short"):
            contexts.append(context)
            return "AAA-1 is with Sara."
        with patch.dict(sys.modules, {"semantic_search": fake}), \
                patch.object(ag, "fetch_ticket_bundle", details), patch.object(ag, "call_llm", llm):
            result = ag._open_question_result("who works on login?", object())
        self.assertEqual(seen, ["AAA-1", "AAA-2", "AAA-3"])
        self.assertIn("Reporter: Omar", contexts[0])
        self.assertEqual(result["answer"], "AAA-1 is with Sara.")

    def _people_ctx(self, account=None):
        import query_engine as qe
        return qe.AccessContext("t", ("AAA",), account)

    def _check(self, plan_json, people, account=None):
        import analytics
        plan = self._plan(plan_json)
        with patch.object(analytics, "known_people", lambda ctx: people):
            return plan, analytics.check_people(plan, self._people_ctx(account), True)

    def test_a_name_resolves_to_one_real_person(self):
        plan, question = self._check('{"kind":"aggregate","assignee":"fatma"}', ["Fatma Ali", "Sara"])
        self.assertIsNone(question)
        self.assertEqual(plan["assignee"], "Fatma Ali")

    def test_two_matches_ask_and_no_match_says_so(self):
        _, question = self._check('{"kind":"aggregate","assignee":"Sara"}', ["Sara A", "Sara B"])
        self.assertIn("Sara A", question)
        self.assertIn("Sara B", question)
        _, question = self._check('{"kind":"aggregate","assignee":"Omar"}', ["Sara A"])
        self.assertIn("Omar", question)

    def test_my_tickets_need_a_known_account_and_filter_on_it(self):
        import analytics
        _, question = self._check('{"kind":"aggregate","me":true}', [])
        self.assertIsNotNone(question)
        plan = self._plan('{"kind":"aggregate","me":true}')
        calls = []

        def fake(query, **params):
            calls.append((query, params))
            return [{"total": 4}]
        with patch.object(analytics, "run_query", fake):
            result = analytics.run_plan(plan, self._people_ctx("acc-1"))
        self.assertEqual(result["total"], 4)
        self.assertEqual(calls[0][1]["me"], "acc-1")
        self.assertIn("accountId: $me", calls[0][0])

    def test_a_people_lookup_failure_never_breaks_the_planner(self):
        import analytics

        def down(*a, **k):
            raise RuntimeError("down")
        with patch.object(analytics, "run_query", down):
            self.assertIn("People: unknown", analytics.planner_prompt("q", self._people_ctx()))

    def test_llm_reply_without_any_ticket_is_no_results(self):
        import answer_generator as ag
        hit = {"key": "AAA-1", "summary": "Login", "status": "To Do", "assignee": "S", "score": 0.6}
        fake = types.SimpleNamespace(semantic_search=lambda q, c: [hit])
        with patch.dict(sys.modules, {"semantic_search": fake}), \
                patch.object(ag, "_top_ticket_details", lambda h, c: ([], [])), \
                patch.object(ag, "call_llm", lambda *a, **k: "No tickets are about this."):
            self.assertEqual(ag._open_question_result("database", None)["status"], "no_results")

    def test_exact_words_raise_a_ticket_and_keyword_failure_keeps_search_working(self):
        import query_engine as qe
        import semantic_search as ss
        ctx = qe.AccessContext("t", ("AAA",))
        row = lambda uid, key, v: ({"uid": uid, "rkey": key, "summary": key, "status": "To Do", "url": "u",
                                    "project": "AAA", "assignee": "S", "emb": v}, v, 1.0)
        vectors = [row("a", "AAA-1", [0.6, 0.8]), row("b", "AAA-2", [0.62, 0.78])]

        def query(cypher, **params):
            if "size([word IN" in cypher:
                self.assertEqual(params["words"], ["oauth"])
                return [{"uid": "a", "found": 1}]
            return [{"uid": "a"}, {"uid": "b"}]
        with patch.object(ss, "_load_vectors", lambda c: vectors), patch.object(ss, "embed_texts", lambda t: [[1.0, 0.0]]), \
                patch.object(ss, "run_query", query):
            self.assertEqual([h["key"] for h in ss.semantic_search("tickets about OAuth", ctx, min_score=0)],
                             ["AAA-1", "AAA-2"])

        def keyword_down(cypher, **params):
            if "size([word IN" in cypher:
                raise RuntimeError("down")
            return [{"uid": "a"}, {"uid": "b"}]
        with patch.object(ss, "_load_vectors", lambda c: vectors), patch.object(ss, "embed_texts", lambda t: [[1.0, 0.0]]), \
                patch.object(ss, "run_query", keyword_down):
            self.assertEqual(ss.semantic_search("OAuth", ctx, min_score=0)[0]["key"], "AAA-2")

    def test_status_transitions_and_who_changed_them_come_from_the_graph(self):
        import analytics
        plan = '{"kind":"aggregate","metric":"changes","to_status":"Done","group_by":"assignee"}'
        result, calls = self._execute(plan, [[{"n": 10}], [], [{"name": "Ihab", "n": 10}]])
        self.assertEqual(calls[0][1]["to_status"], "Done")
        self.assertIn("e.to_name", calls[0][0])
        self.assertIn("Ihab: 10", analytics.format_answer(self._plan(plan), result, False))

    def test_epic_ranking_filters_parents_and_hides_the_misleading_total(self):
        import analytics
        plan = '{"kind":"aggregate","group_by":"parent","parent_type":"Epic"}'
        result, calls = self._execute(plan, [[{"total": 274}], [{"name": "A-1: X", "n": 8}]])
        self.assertIn("par.issuetype", calls[1][0])
        text = analytics.format_answer(self._plan(plan), result, False)
        self.assertNotIn("274", text)
        self.assertIn("Most: A-1: X (8).", text)

    def test_comment_search_matches_any_word(self):
        plan = '{"kind":"aggregate","metric":"comments","text":"OAuth state"}'
        _, calls = self._execute(plan, [[{"n": 0}], []])
        self.assertEqual(calls[0][1]["text_words"], ["oauth", "state"])

    def test_reading_comments_uses_the_llm_and_a_wrong_key_falls_back(self):
        import answer_generator as ag
        import query_engine as qe
        ctx = qe.AccessContext("t", ("AAA",))
        plan = self._plan('{"kind":"aggregate","metric":"comments","read_comments":true}')
        records = [{"key": "AAA-1", "url": "u", "at": "2026-11-01", "who": "S", "text": "QA rejected it"}]
        result = {"total": 1, "groups": [], "tickets": [], "records": records, "any_due_date": True}
        with patch.object(ag.analytics, "check_people", lambda *a: None), \
                patch.object(ag.analytics, "run_plan", lambda p, c: result):
            with patch.object(ag, "call_llm", lambda *a, **k: "AAA-1 was rejected by QA."):
                self.assertEqual(ag._aggregate_result("who rejected?", plan, ctx)["answer"], "AAA-1 was rejected by QA.")
            with patch.object(ag, "call_llm", lambda *a, **k: "ZZZ-9 was rejected."):
                self.assertIn("AAA-1 (2026-11-01, S)", ag._aggregate_result("who rejected?", plan, ctx)["answer"])

    def test_search_path_gives_the_llm_relations(self):
        import answer_generator as ag
        hit = {"key": "AAA-1", "summary": "Filter", "status": "To Do", "assignee": "S"}
        bundle = ({"key": "AAA-1", "summary": "Filter"},
                  {"blocks": {"key": "AAA-1", "items": [{"key": "BBB-2", "summary": "Y", "status": "To Do", "assignee": "S"}]}})
        with patch.object(ag, "fetch_ticket_bundle", lambda h, c: bundle):
            contexts, facts = ag._top_ticket_details([hit], object())
        self.assertTrue(any("BBB-2" in c for c in contexts))
        self.assertIn("BBB-2", facts)

    def test_a_long_ticket_cannot_push_relations_out_of_the_context(self):
        import answer_generator as ag
        hits = [{"key": f"AAA-{i}"} for i in range(1, 4)]

        def bundle(hit, ctx):
            key = hit["key"]
            return ({"key": key, "summary": "S", "description": "x" * 20000},
                    {"blocks": {"key": key, "items": [{"key": "BBB-" + key[-1], "summary": "Y", "status": "To Do", "assignee": "S"}]}})
        with patch.object(ag, "fetch_ticket_bundle", bundle):
            contexts, _ = ag._top_ticket_details(hits, object())
        joined = "\n".join(contexts)[:ag.MAX_CONTEXT_CHARS]
        for key in ("BBB-1", "BBB-2", "BBB-3"):
            self.assertIn(key, joined)

    def test_a_comment_answer_may_name_tickets_mentioned_in_the_comments(self):
        import answer_generator as ag
        import query_engine as qe
        plan = self._plan('{"kind":"aggregate","metric":"comments","read_comments":true}')
        records = [{"key": "AAA-1", "url": "u", "at": "2026-11-01", "who": "S", "text": "Blocked by BBB-2"}]
        result = {"total": 1, "groups": [], "tickets": [], "records": records, "any_due_date": True}
        with patch.object(ag.analytics, "check_people", lambda *a: None), \
                patch.object(ag.analytics, "run_plan", lambda p, c: result), \
                patch.object(ag, "call_llm", lambda *a, **k: "AAA-1 is blocked by BBB-2."):
            answer = ag._aggregate_result("blockers?", plan, qe.AccessContext("t", ("AAA",)))
        self.assertEqual(answer["answer"], "AAA-1 is blocked by BBB-2.")

    def test_a_ticket_picked_beyond_the_closest_ones_gets_its_details_before_answering(self):
        import answer_generator as ag
        hits = [{"key": f"AAA-{i}", "summary": f"T{i}", "status": "To Do", "assignee": "S", "score": 0.6}
                for i in range(1, 6)]
        fake = types.SimpleNamespace(semantic_search=lambda q, c: hits)
        replies = ["AAA-5 blocks nothing.", "AAA-5 blocks BBB-1."]
        contexts = []

        def llm(question, context, style="short"):
            contexts.append(context)
            return replies[len(contexts) - 1]

        def bundle(hit, ctx):
            items = [{"key": "BBB-1", "summary": "Y", "status": "To Do", "assignee": "S"}] if hit["key"] == "AAA-5" else []
            return {"key": hit["key"], "summary": hit["summary"]}, {"blocks": {"key": hit["key"], "items": items}}
        with patch.dict(sys.modules, {"semantic_search": fake}), \
                patch.object(ag, "fetch_ticket_bundle", bundle), patch.object(ag, "call_llm", llm):
            result = ag._open_question_result("does it block anything?", object())
        self.assertEqual(result["answer"], "AAA-5 blocks BBB-1.")
        self.assertIn("BBB-1", contexts[1])

    def test_model_typography_cannot_hide_keys_or_names(self):
        import answer_generator as ag
        text = "SYNDATA\u20113 is with Fatma\u202fSaeed"
        reply = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=text))])
        client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=lambda **k: reply)))
        with patch.object(ag, "_get_client", lambda: client):
            self.assertEqual(ag._complete("p"), "SYNDATA-3 is with Fatma Saeed")

    def test_without_llm_a_common_word_cannot_make_a_weak_match_look_strong(self):
        import answer_generator as ag
        hit = {"key": "AAA-1", "summary": "Today", "status": "To Do", "assignee": "S", "score": 0.5, "meaning_score": 0.38}
        fake = types.SimpleNamespace(semantic_search=lambda q, c: [hit])
        with patch.dict(sys.modules, {"semantic_search": fake}), patch.object(ag, "call_llm", lambda *a, **k: None):
            self.assertEqual(ag._open_question_result("weather today", None)["status"], "no_results")

    def test_compound_and_date_plans_are_validated(self):
        plan = self._plan('{"kind":"compound","questions":["a?","b?"]}')
        self.assertEqual(plan["questions"], ["a?", "b?"])
        self.assertIsNone(self._plan('{"kind":"compound","questions":["only one"]}'))
        self.assertIsNone(self._plan('{"kind":"compound","questions":["a","b","c","d"]}'))
        self.assertIsNone(self._plan('{"kind":"aggregate","since_date":"2026-13-40"}'))
        self.assertIsNone(self._plan('{"kind":"aggregate","since_date":"x\' OR 1=1"}'))

    def test_date_period_filters_tickets_and_records(self):
        plan = '{"kind":"aggregate","date_field":"created","since_date":"2026-10-01","until_date":"2026-11-01"}'
        _, calls = self._execute(plan, [[{"total": 1}]])
        self.assertIn("w.created >= $since", calls[0][0])
        self.assertIn("w.created < $until", calls[0][0])
        self.assertEqual((calls[0][1]["since"], calls[0][1]["until"]), ("2026-10-01", "2026-11-01"))
        plan = '{"kind":"aggregate","metric":"changes","since_date":"2026-10-01","until_date":"2026-11-01"}'
        _, calls = self._execute(plan, [[{"n": 0}], []])
        self.assertIn("e.changed_at < $until", calls[0][0])

    def test_compound_answers_each_part_and_never_nests(self):
        import answer_generator as ag
        import query_engine as qe
        ctx = qe.AccessContext("t", ("AAA",))
        plans = iter(['{"kind":"compound","questions":["one?","two?"]}',
                      '{"kind":"out_of_scope"}', '{"kind":"compound","questions":["x?","y?"]}'])
        with patch.object(ag, "_complete", lambda p: next(plans)), \
                patch.object(ag, "_open_question_result", lambda q, c, s=None: {"status": "ok", "answer": "searched", "links": []}):
            result = ag._keyless_question_result("both?", ctx)
        self.assertEqual(result["status"], "ok")
        self.assertIn("one?", result["answer"])
        self.assertIn("two?\nsearched", result["answer"])

    def _comment_answer(self, pick, written="AAA-1 was rejected."):
        import answer_generator as ag
        import query_engine as qe
        records = [{"key": "AAA-1", "who": "M", "text": "rejected", "at": "2026-01-01", "url": "u"},
                   {"key": "AAA-2", "who": "M", "text": "retest failed", "at": "2026-01-01", "url": "u"},
                   {"key": "AAA-3", "who": "M", "text": "looks good", "at": "2026-01-01", "url": "u"}]
        result = {"total": 3, "groups": [], "tickets": [], "records": records, "any_due_date": True}
        plan = ag.analytics.parse_plan('{"kind":"aggregate","metric":"comments","read_comments":true}')
        with patch.object(ag.analytics, "check_people", lambda *a: None), \
                patch.object(ag.analytics, "run_plan", lambda *a: result), \
                patch.object(ag, "_complete", lambda p: pick), \
                patch.object(ag, "call_llm", lambda *a, **k: written):
            return ag._aggregate_result("who rejected?", plan, qe.AccessContext("t", ("AAA",)))

    def test_every_picked_comment_ticket_appears_in_the_answer(self):
        result = self._comment_answer('{"answers":["yes","yes","no"]}')
        self.assertIn("AAA-1", result["answer"])
        self.assertIn("AAA-2: retest failed", result["answer"])
        self.assertNotIn("AAA-3", result["answer"])

    def test_no_picked_comment_says_so(self):
        self.assertIn("No comment", self._comment_answer('{"answers":["no","no","no"]}')["answer"])

    def test_a_bad_comment_pick_is_ignored(self):
        for reply in ("nope", '{"answers":["yes"]}', '{"answers":["maybe","no","no"]}', '{"answers":"yes"}'):
            self.assertNotIn("AAA-2", self._comment_answer(reply)["answer"])

    def _compound_with_top(self, groups):
        import answer_generator as ag
        import query_engine as qe
        ctx = qe.AccessContext("t", ("AAA",))
        asked = []

        def part(question, c, allow_compound=True):
            asked.append(question)
            top = ag.analytics.single_top({"groups": groups}) if len(asked) == 1 else None
            return {"status": "ok", "answer": "n", "links": [], "top": top}
        with patch.object(ag, "_keyless_question_result", part):
            return ag._compound_result(["who has most?", "done for TOP_RESULT?"], ctx), asked

    def test_a_later_compound_part_uses_the_earlier_top_result(self):
        result, asked = self._compound_with_top([{"name": "Martina", "count": 65}, {"name": "Ihab", "count": 63}])
        self.assertEqual(asked[1], "done for Martina?")
        self.assertNotIn("TOP_RESULT", result["answer"])

    def test_a_tie_never_guesses_the_later_compound_part(self):
        result, asked = self._compound_with_top([{"name": "Martina", "count": 65}, {"name": "Ihab", "count": 65}])
        self.assertEqual(len(asked), 1)
        self.assertIn("no single result", result["answer"])
        self.assertNotIn("TOP_RESULT", result["answer"])

    def test_a_compound_part_naming_a_ticket_uses_the_ticket_path(self):
        import answer_generator as ag
        import query_engine as qe
        ctx = qe.AccessContext("t", ("AAA",))
        calls = []
        real = ag.answer_key_question

        def keys(question, c):
            calls.append(question)
            if "AAA-1" in question:
                return [{"type": "not_found", "key": "AAA-1", "message": "No ticket found with key AAA-1."}]
            return real(question, c)
        with patch.object(ag, "answer_key_question", keys):
            result = ag._compound_result(["status of AAA-1?"], ctx)
        self.assertEqual(calls, ["status of AAA-1?"])
        self.assertIn("No ticket found", result["answer"])

    def test_unanswered_questions_are_recorded_only_when_enabled(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "unanswered.jsonl")
            with patch.dict(os.environ, {"UNANSWERED_LOG_PATH": path}):
                ai_service._record_unanswered("q1", "company", "no_results", "c1")
                ai_service._record_unanswered("q2", "company", "ok", "c2")
            with open(path, encoding="utf-8") as saved:
                lines = [json.loads(line) for line in saved]
            self.assertEqual([line["question"] for line in lines], ["q1"])
            self.assertNotIn("company", lines[0]["company"])
        env = {k: v for k, v in os.environ.items() if k != "UNANSWERED_LOG_PATH"}
        with patch.dict(os.environ, env, clear=True):
            ai_service._record_unanswered("q3", "company", "no_results", "c3")

    def test_empty_arabic_period_reads_naturally(self):
        import analytics
        plan = self._plan('{"kind":"aggregate","since_date":"2026-09-01"}')
        text = analytics.format_answer(plan, {"total": 0, "groups": [], "tickets": [], "records": [], "any_due_date": True}, True)
        self.assertTrue(text.startswith("مفيش تذاكر"))

    def test_identical_questions_reuse_an_answer_only_in_the_same_scope(self):
        import query_engine as qe
        calls = []

        def answer(question, ctx):
            calls.append(ctx.tenant_id)
            return {"status": "ok", "answer": "a", "links": []}
        with patch.object(ai_service, "CACHE_SECONDS", 60), patch.dict(ai_service._answers, clear=True), \
                patch.object(ai_service, "generate_answer_result", answer):
            first = qe.AccessContext("t1", ("AAA",))
            ai_service._cached_answer("Who  has tickets?", first)
            ai_service._cached_answer("who has tickets?", first)
            ai_service._cached_answer("who has tickets?", qe.AccessContext("t2", ("AAA",)))
            ai_service._cached_answer("who has tickets?", qe.AccessContext("t1", ("BBB",)))
            ai_service._cached_answer("who has tickets?", qe.AccessContext("t1", ("AAA",), "acc"))
        self.assertEqual(calls, ["t1", "t2", "t1", "t1"])

    def test_failed_answers_are_not_cached(self):
        import query_engine as qe
        calls = []

        def answer(question, ctx):
            calls.append(1)
            return {"status": "no_results", "answer": "a", "links": []}
        with patch.object(ai_service, "CACHE_SECONDS", 60), patch.dict(ai_service._answers, clear=True), \
                patch.object(ai_service, "generate_answer_result", answer):
            ctx = qe.AccessContext("t", ("AAA",))
            ai_service._cached_answer("q", ctx)
            ai_service._cached_answer("q", ctx)
        self.assertEqual(len(calls), 2)

    def test_empty_values_are_left_out_of_the_llm_context(self):
        import answer_generator as ag
        context = ag.build_ticket_context({"key": "AAA-1", "duedate": None})
        self.assertIn("Due date: None", context)
        self.assertIn("Comments: None", context)
        self.assertNotIn("Reporter", context)
        self.assertNotIn("Labels", context)

    def test_listed_tickets_use_number_order(self):
        import analytics
        _, calls = self._execute('{"kind":"aggregate","list_tickets":true}', [[{"total": 1}], []])
        self.assertIn("toInteger(split(w.key, '-')[-1])", calls[1][0])

    def test_answers_say_where_they_came_from(self):
        import answer_generator as ag
        result = {"total": 0, "groups": [], "tickets": [], "records": [], "any_due_date": True}
        with patch.object(ag.analytics, "check_people", lambda *a: None), \
                patch.object(ag.analytics, "run_plan", lambda p, c: result):
            answer = ag._aggregate_result("q", self._plan('{"kind":"aggregate"}'), None)
        self.assertEqual(answer["source"], "graph_query")

    def test_smoke_test_reads_a_count_from_an_answer(self):
        import project_smoke_test as smoke
        self.assertTrue(smoke.contains_number("Number of tickets: 505.", 505))
        self.assertFalse(smoke.contains_number("Number of tickets: 4.", 505))

    def test_search_reply_none_means_no_results(self):
        import answer_generator as ag
        hit = {"key": "AAA-1", "summary": "Login", "status": "To Do", "assignee": "S", "score": 0.6}
        fake_search = types.SimpleNamespace(semantic_search=lambda q, c: [hit])
        with patch.dict(sys.modules, {"semantic_search": fake_search}), \
                patch.object(ag, "call_llm", lambda *a, **k: "NONE"):
            self.assertEqual(ag._open_question_result("database", None)["status"], "no_results")

    def test_transient_webhook_failure_is_retried(self):
        result = ac.rel.EventResult("failed", "failed", retryable=True, error="TransientError")
        p = ac.EventProcessor(pf.session_factory(self.tx), self.catalog, handle=lambda *a, **k: result)
        self.assertEqual(p.process(message(rawWebhook={"webhookEvent": "x"})).action, "retry")

    def test_routing_of_decisions(self):
        self.assertEqual(ac.route(ac.Decision("ack"), 0, 5)[0], None)
        self.assertEqual(ac.route(ac.Decision("retry", "x"), 4, 5)[:2], ("retry_exchange", "retry"))
        self.assertEqual(ac.route(ac.Decision("retry", "x"), 4, 5)[2], {"x-retry-count": 5})
        self.assertEqual(ac.route(ac.Decision("retry", "x"), 5, 5)[:2], ("dead_exchange", "dead"))
        self.assertIn("retries exhausted", ac.route(ac.Decision("retry", "x"), 5, 5)[2]["x-dead-letter-reason"])


class RecordingTx:
    """Answers the issue lookup and records every statement."""
    def __init__(self):
        self.calls = []

    def run(self, query, **params):
        self.calls.append((" ".join(query.split()), params))
        row = {"uid": "u-" + str(params.get("id")), "key": "FIX-1", "project_key": "FIX"} if "w.jira_id = $id" in query else None
        return SimpleNamespace(single=lambda: row)


class NewEventHandlerTests(unittest.TestCase):
    def test_issue_link_direction_and_type_come_from_the_event(self):
        tx, link = RecordingTx(), {"sourceIssueId": "1", "destinationIssueId": "2",
                                   "issueLinkType": {"outwardName": "blocks"}}
        payload = {"issueLink": link}
        self.assertEqual(ac.webhook_handler.on_issuelink(tx, payload, "created", T, {"site": CLOUD}), "upserted")
        query, params = tx.calls[-1]
        self.assertIn("MERGE (a)-[r:BLOCKS]->(b)", query)
        self.assertEqual((params["a"], params["b"]), ("u-1", "u-2"))
        self.assertEqual(ac.webhook_handler.on_issuelink(tx, payload, "deleted", T, {"site": CLOUD}), "deleted")
        self.assertIn("-[r:BLOCKS]->", tx.calls[-1][0])
        self.assertIn("DELETE r", tx.calls[-1][0])

    def test_attachment_deleted_removes_by_uid(self):
        tx = RecordingTx()
        self.assertEqual(ac.webhook_handler.on_attachment(tx, {"attachment": {"id": "7"}}, "deleted", T, {"site": CLOUD}), "deleted")
        self.assertEqual(tx.calls[-1][1]["uid"], f"{T}:site:{CLOUD}:attachment:7")

    def test_malformed_events_are_rejected(self):
        tx = RecordingTx()
        self.assertEqual(ac.webhook_handler.on_attachment(tx, {}, "created", T, {"site": CLOUD}), "no_attachment_object")
        self.assertEqual(ac.webhook_handler.on_issuelink(tx, {"issueLink": {}}, "created", T, {"site": CLOUD}), "no_issuelink_object")


class TenantHandlerTests(unittest.TestCase):
    def test_delete_tenant_requires_a_tenant(self):
        with self.assertRaises(ValueError):
            ingest.delete_tenant(None, "")


@unittest.skipUnless(os.getenv("RABBITMQ_INTEGRATION") == "1", "requires RABBITMQ_INTEGRATION=1 and a broker")
class RabbitRoundTripTests(unittest.TestCase):
    def setUp(self):
        tag = uuid.uuid4().hex[:8]
        self.s = ac.Settings(exchange=f"t.events.{tag}", queue=f"t.ai.{tag}", retry_exchange=f"t.retry.{tag}",
                             retry_queue=f"t.ai.retry.{tag}", dead_exchange=f"t.dlx.{tag}",
                             dead_queue=f"t.ai.dead.{tag}", retry_ttl_ms=100, max_retries=2)
        self.conn = ac.connect(self.s)
        self.ch = self.conn.channel()
        ac.declare_topology(self.ch, self.s)

    def tearDown(self):
        for q in (self.s.queue, self.s.retry_queue, self.s.dead_queue):
            self.ch.queue_delete(q)
        for e in (self.s.exchange, self.s.retry_exchange, self.s.dead_exchange):
            self.ch.exchange_delete(e)
        self.conn.close()

    def run_consumer(self, process, stop_when, publish):
        consumer = ac.Consumer(SimpleNamespace(process=process), self.s)
        import threading
        thread = threading.Thread(target=consumer.run_once)
        thread.start()
        for body, key in publish:
            self.ch.basic_publish(self.s.exchange, key, body, properties=ac.pika.BasicProperties(message_id="m1"))
        deadline = time.time() + 20
        while not stop_when() and time.time() < deadline:
            time.sleep(0.05)
        consumer.stop()
        thread.join(10)
        self.assertTrue(stop_when())

    def test_both_routing_keys_reach_the_ai_queue_and_are_acked(self):
        got = []

        def process(body):
            got.append(body)
            return ac.Decision("ack")
        self.run_consumer(process, lambda: len(got) == 2, [(b"a", "jira.issue.updated"), (b"b", "ai.import.issue")])
        self.assertEqual(self.ch.queue_declare(self.s.queue, passive=True).method.message_count, 0)

    def test_retry_comes_back_to_the_ai_queue_then_goes_to_dead_letter_with_a_reason(self):
        calls = []

        def process(body):
            calls.append(body)
            return ac.Decision("retry", "boom")

        def dead():
            return self.ch.queue_declare(self.s.dead_queue, passive=True).method.message_count == 1
        self.run_consumer(process, dead, [(b"x", "jira.issue.updated")])
        self.assertEqual(len(calls), 3)
        method, props, body = self.ch.basic_get(self.s.dead_queue, auto_ack=True)
        self.assertEqual(body, b"x")
        self.assertIn("retries exhausted: boom", props.headers["x-dead-letter-reason"])


if __name__ == "__main__":
    unittest.main()