"""The live meeting helper: new lines only, checked quotes and references, no repeated help, the end."""
import json
import unittest

from syntrace_ai.meetings import session as live
from syntrace_ai.meetings.errors import MeetingError
from syntrace_ai.graph.query_engine import AccessContext

CTX = AccessContext("acme", ("SYNT",))
OTHER = AccessContext("other", ("SYNT",))

PART1 = ("Sara Client: أهلًا يا جماعة.\n"
         "Sara Client: عايزين الدفع يكون بالفيزا بس.\n"
         "Sara Client: والتطبيق يبقى سريع.")
PART2 = PART1 + ("\nSara Client: وكمان عايزين dark mode في الـ release ده.\n"
                 "Sara Client: بصراحة إيهاب اتأخر علينا تاني ومش مركز.")
MEMORY = [{"uid": "acme:req:1", "text": "Dark mode is dropped from this release.", "status": "dropped",
           "project_key": "SYNT", "changes": [{"type": "created", "meeting": "Kickoff", "meeting_date": "2026-11-05"}]}]
QUESTIONS = [{"uid": "acme:q:1", "text": "Which payment methods are needed?", "meeting": "Kickoff",
              "date": "2026-11-05", "quote": "لسه بنفكر"}]


class FakeGraph:
    """Just enough of the graph for the session's queries."""
    def __init__(self):
        self.rows = {}

    def __call__(self, query, **p):
        q = " ".join(query.split())
        if q.startswith("MATCH (l:LiveSession {uid: $uid, tenant_id: $tenant})"):
            s = self.rows.get(p["uid"])
            ok = s and s["tenant_id"] == p["tenant"] and s["project_key"] in p["allowed"]
            return [{"l": dict(s)}] if ok else []
        if q.startswith("MERGE (l:LiveSession"):
            self.rows.setdefault(p["uid"], {"uid": p["uid"], "tenant_id": p["tenant"], "project_key": p["project"],
                                            "session_id": p["sid"], "title": p["title"], "status": p["live"],
                                            "lines_seen": 0, "suggestions": [], "keys": [], "dismissed": []})
            return []
        s = self.rows.get(p.get("uid"))
        if "SET l.dismissed" in q:
            s["dismissed"] += [d for d in p["ids"] if d not in s["dismissed"]]
        elif "SET l.lines_seen" in q:
            s.update(lines_seen=p["seen"], suggestions=p["given"], keys=p["keys"], partial=p.get("partial"))
        elif "SET l.status" in q:
            s.update(status=p["ended"], source_id=p["source"])
        elif "DETACH DELETE" in q:
            self.rows.pop(p["uid"])
        return []


def model(rows, answer=None, quote=None, prompts=None):
    def llm(prompt):
        if prompts is not None:
            prompts.append(prompt)
        return json.dumps({"suggestions": rows, "answer": answer, "answer_quote": quote}, ensure_ascii=False)
    return llm


def service(llm, submitted=None):
    return live.LiveSessions(FakeGraph(), llm, history=lambda ctx, q, p: MEMORY,
                             open_questions=lambda ctx, p: QUESTIONS,
                             submit=lambda *a, **k: submitted.append(a) if submitted is not None else None)


class LiveSessionTests(unittest.TestCase):
    def test_only_new_lines_are_read_and_help_is_not_repeated(self):
        prompts = []
        rows = [{"kind": "ask_client", "text": "Ask whether cash on delivery is needed too.",
                 "quote": "عايزين الدفع يكون بالفيزا بس."}]
        svc = service(model(rows, prompts=prompts))
        svc.start(CTX, "m1", "synt", "Sprint review")
        first = svc.assist(CTX, "m1", PART1)
        self.assertEqual([s["kind"] for s in first["suggestions"]], ["ask_client"])
        self.assertEqual(first["suggestions"][0]["lines"], [2])
        second = svc.assist(CTX, "m1", PART2)
        self.assertEqual(second["suggestions"], [])            # the same help is not given twice
        self.assertIn("4: Sara Client: وكمان عايزين dark mode", prompts[1])
        self.assertNotIn("2: Sara Client: عايزين الدفع", prompts[1].split("<<<NEW")[1])   # old lines are context only

    def test_a_conflict_names_the_earlier_meeting_and_needs_a_real_requirement(self):
        rows = [{"kind": "conflict", "text": "Dark mode was dropped in Kickoff; now the client wants it.",
                 "quote": "وكمان عايزين dark mode في الـ release ده.", "ref": "R1"},
                {"kind": "conflict", "text": "Made up.", "quote": "وكمان عايزين dark mode في الـ release ده.",
                 "ref": "R9"}]
        svc = service(model(rows))
        svc.start(CTX, "m2", "SYNT")
        found = svc.assist(CTX, "m2", PART2)["suggestions"]
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]["ref"]["where"], "Kickoff (2026-11-05)")

    def test_invented_quotes_blame_and_unknown_kinds_are_refused(self):
        rows = [{"kind": "risk", "text": "Visa only may block users.", "quote": "لازم نخلص في يومين"},
                {"kind": "risk", "text": "Ihab is late and not focused.", "quote": "بصراحة إيهاب اتأخر علينا تاني ومش مركز."},
                {"kind": "gossip", "text": "x", "quote": "أهلًا يا جماعة."}]
        svc = service(model(rows))
        svc.start(CTX, "m3", "SYNT")
        self.assertEqual(svc.assist(CTX, "m3", PART2)["suggestions"], [])

    def test_a_reminder_points_at_an_open_question(self):
        svc = service(model([{"kind": "reminder", "text": "Kickoff left payment methods open: ask now.",
                              "quote": None, "ref": "Q1"}]))
        svc.start(CTX, "m4", "SYNT")
        found = svc.assist(CTX, "m4", PART1)["suggestions"]
        self.assertEqual(found[0]["ref"]["type"], "open_question")

    def test_the_teams_question_is_answered_with_a_checked_quote(self):
        svc = service(model([], answer="Visa only so far.", quote="الدفع يكون بالفيزا بس"))
        svc.start(CTX, "m5", "SYNT")
        result = svc.assist(CTX, "m5", PART1, question="Which payment methods did they ask for?")
        self.assertEqual(result["answer"]["lines"], [2])
        svc2 = service(model([], answer="Visa and PayPal.", quote="فيزا وباي بال"))
        svc2.start(CTX, "m6", "SYNT")
        self.assertIsNone(svc2.assist(CTX, "m6", PART1, question="payment?")["answer"]["quote"])

    def test_a_line_still_being_spoken_is_read_again_when_it_grows(self):
        prompts = []
        svc = service(lambda p: prompts.append(p) or "{}")
        svc.start(CTX, "m9", "SYNT")
        svc.assist(CTX, "m9", "Client: hello\nClient: we need the login to take under")
        svc.assist(CTX, "m9", "Client: hello\nClient: we need the login to take under two seconds")
        self.assertEqual(len(prompts), 2)
        self.assertIn("under two seconds", prompts[1])
        svc.assist(CTX, "m9", "Client: hello\nClient: we need the login to take under two seconds")
        self.assertEqual(len(prompts), 2)   # not grown: no new call

    def test_nothing_new_costs_no_model_call(self):
        calls = []
        svc = service(lambda p: calls.append(p) or "{}")
        svc.start(CTX, "m7", "SYNT")
        svc.assist(CTX, "m7", PART1)
        svc.assist(CTX, "m7", PART1)
        self.assertEqual(len(calls), 1)

    def test_end_lists_what_was_not_asked_and_sends_the_transcript_to_review(self):
        submitted = []
        rows = [{"kind": "ask_client", "text": "Ask about cash on delivery.", "quote": "عايزين الدفع يكون بالفيزا بس."},
                {"kind": "ask_client", "text": "Ask what fast means in seconds.", "quote": "والتطبيق يبقى سريع."}]
        svc = service(model(rows), submitted)
        svc.start(CTX, "m8", "SYNT", "Client sync")
        given = svc.assist(CTX, "m8", PART1)["suggestions"]
        svc.assist(CTX, "m8", PART1, dismiss=[given[0]["id"]])
        ended = svc.end(CTX, "m8", transcript=PART1, meeting_date="2026-11-23")
        self.assertEqual([g["text"] for g in ended["next_meeting"]["not_asked"]], ["Ask what fast means in seconds."])
        self.assertEqual(ended["next_meeting"]["open_questions"], QUESTIONS)
        self.assertEqual(ended["source_id"], "live-m8")
        self.assertEqual(submitted[0][1:4], ("live-m8", "SYNT", "online"))
        with self.assertRaises(MeetingError):
            svc.assist(CTX, "m8", PART2)

    def test_another_company_or_project_cannot_reach_the_session(self):
        svc = service(model([]))
        svc.start(CTX, "m9", "SYNT")
        with self.assertRaises(MeetingError) as caught:
            svc.view(OTHER, "m9")
        self.assertEqual(caught.exception.status, 404)
        with self.assertRaises(MeetingError):
            svc.start(CTX, "m10", "OTHERPROJ")

    def test_contact_numbers_are_masked_before_the_model_sees_them(self):
        prompts = []
        svc = service(model([], prompts=prompts))
        svc.start(CTX, "m11", "SYNT")
        svc.assist(CTX, "m11", "Sara Client: كلمني على 01012345678 بكرة.")
        self.assertNotIn("01012345678", prompts[0])


if __name__ == "__main__":
    unittest.main()


class MissingAndWrapUpTests(unittest.TestCase):
    MEETING = ("Sara Client: عايزين الناس تدفع أونلاين في التطبيق.\n"
               "Fatma (You): تمام.\n"
               "Sara Client: وعايزين تقرير بالمبيعات.\n"
               "Fatma (You): ماشي، حاجة تانية؟")

    def test_a_missing_detail_points_at_the_request(self):
        rows = [{"kind": "missing", "text": "Ask which payment methods and whether refunds are needed.",
                 "quote": "عايزين الناس تدفع أونلاين في التطبيق."},
                {"kind": "missing", "text": "No quote, so not kept.", "quote": None}]
        svc = service(model(rows))
        svc.start(CTX, "w1", "SYNT")
        found = svc.assist(CTX, "w1", self.MEETING)["suggestions"]
        self.assertEqual([(f["kind"], f["lines"]) for f in found], [("missing", [1])])

    def test_wrap_up_reads_the_whole_meeting_on_its_own_model_and_skips_what_was_given(self):
        live_rows = [{"kind": "missing", "text": "Ask which payment methods and whether refunds are needed.",
                      "quote": "عايزين الناس تدفع أونلاين في التطبيق."}]
        wrap_prompts = []

        def wrap_model(prompt):
            wrap_prompts.append(prompt)
            return json.dumps({"suggestions": [
                {"kind": "missing", "text": "Ask which payment methods and whether refunds are needed.",
                 "quote": "عايزين الناس تدفع أونلاين في التطبيق."},
                {"kind": "missing", "text": "Ask who sees the sales report and how often.",
                 "quote": "وعايزين تقرير بالمبيعات."},
                {"kind": "reminder", "text": "Kickoff left the payment methods open: ask now.", "quote": None,
                 "ref": "Q1"}]}, ensure_ascii=False)
        svc = live.LiveSessions(FakeGraph(), model(live_rows), history=lambda c, q, p: MEMORY,
                                open_questions=lambda c, p: QUESTIONS, wrap_llm=wrap_model)
        svc.start(CTX, "w2", "SYNT")
        svc.assist(CTX, "w2", self.MEETING)
        wrapped = svc.wrap_up(CTX, "w2", self.MEETING)["suggestions"]
        self.assertEqual([w["text"] for w in wrapped], ["Ask who sees the sales report and how often.",
                                                        "Kickoff left the payment methods open: ask now."])
        self.assertIn("1: Sara Client: عايزين الناس تدفع", wrap_prompts[0])
        self.assertIn("- Ask which payment methods", wrap_prompts[0])   # told what was already given
        ended = svc.end(CTX, "w2")
        self.assertEqual(len(ended["next_meeting"]["not_asked"]), 3)

    def test_wrap_up_after_the_end_is_refused(self):
        svc = service(model([]))
        svc.start(CTX, "w3", "SYNT")
        svc.end(CTX, "w3")
        with self.assertRaises(MeetingError):
            svc.wrap_up(CTX, "w3", self.MEETING)


class LiveApiTests(unittest.TestCase):
    def setUp(self):
        from unittest.mock import patch
        from fastapi.testclient import TestClient
        from syntrace_ai.api import ai_service
        from syntrace_ai.meetings import meeting_notes as mn
        from test_meeting_notes import HEADERS
        self.headers = HEADERS
        self.client = TestClient(ai_service.app)
        self.svc = service(model([{"kind": "ask_client", "text": "Ask about cash.",
                                   "quote": "عايزين الدفع يكون بالفيزا بس."}]))
        patcher = patch.object(mn, "live_sessions", return_value=self.svc)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.who = {"companyId": "acme", "allowedProjects": ["synt"]}

    def test_start_assist_end_in_camel_case(self):
        started = self.client.put("/live-sessions/m1", json={**self.who, "projectKey": "SYNT", "title": "Sync"},
                                  headers=self.headers)
        self.assertEqual(started.status_code, 200)
        self.assertEqual(started.json()["status"], "live")
        assisted = self.client.post("/live-sessions/m1/assist", json={**self.who, "transcript": PART1},
                                    headers=self.headers).json()
        self.assertEqual(assisted["suggestions"][0]["kind"], "ask_client")
        self.assertEqual(assisted["linesSeen"], 2)   # the last line may still be spoken: read again next time
        wrapped = self.client.post("/live-sessions/m1/wrap-up", json={**self.who, "transcript": PART1},
                                   headers=self.headers)
        self.assertEqual(wrapped.status_code, 200)
        ended = self.client.post("/live-sessions/m1/end", json=self.who, headers=self.headers).json()
        self.assertEqual(ended["nextMeeting"]["notAsked"][0]["text"], "Ask about cash.")
        self.assertEqual(ended["nextMeeting"]["openQuestions"][0]["meeting"], "Kickoff")

    def test_unknown_session_is_404_and_bad_id_400(self):
        self.assertEqual(self.client.post("/live-sessions/none/assist", json={**self.who, "transcript": "x"},
                                          headers=self.headers).status_code, 404)
        self.assertEqual(self.client.put("/live-sessions/a b", json={**self.who, "projectKey": "SYNT"},
                                         headers=self.headers).status_code, 400)

    def test_without_the_internal_key_nothing_runs(self):
        self.assertEqual(self.client.put("/live-sessions/m1", json={**self.who, "projectKey": "SYNT"}).status_code, 401)


class MemoryApiTests(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        from syntrace_ai.api import ai_service
        from test_meeting_notes import HEADERS
        self.headers, self.client = HEADERS, TestClient(ai_service.app)

    def test_requirements_and_open_questions(self):
        from unittest.mock import patch
        from syntrace_ai.meetings import meeting_notes as mn
        story = [{"uid": "acme:req:1", "text": "Visa only", "status": "active", "project_key": "SYNT",
                  "changes": [{"type": "created", "after": "Visa", "meeting": "Kickoff", "meeting_date": "2026-11-05"}]}]
        with patch.object(mn, "requirement_history", return_value=story), patch.object(mn, "_check_scope"):
            body = self.client.get("/projects/synt/requirements?companyId=acme&allowedProjects=SYNT",
                                   headers=self.headers).json()
        self.assertEqual(body["requirements"][0]["changes"][0]["meeting"], "Kickoff")
        with patch.object(mn, "open_questions", return_value=QUESTIONS):
            body = self.client.get("/projects/SYNT/open-questions?companyId=acme&allowedProjects=SYNT",
                                   headers=self.headers).json()
        self.assertEqual(body["openQuestions"][0]["text"], "Which payment methods are needed?")
        with patch.object(mn, "edit_requirement", return_value=story) as edit:
            response = self.client.patch("/requirements/acme:req:1", json={"companyId": "acme", "allowedProjects": ["SYNT"],
                                                                           "text": "Visa and cash", "editedBy": "emp-7"},
                                         headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(edit.call_args.args[1:], ("acme:req:1", "Visa and cash", "emp-7"))

    def test_a_project_outside_the_list_is_refused(self):
        response = self.client.get("/projects/OTHER/requirements?companyId=acme&allowedProjects=SYNT", headers=self.headers)
        self.assertEqual(response.status_code, 403)


FACTS = [{"type": "ticket", "key": "SYNT-12", "text": "Pay by card", "status": "In Progress"},
         {"type": "pull_request", "key": "#45", "ticket": "SYNT-12", "text": "Card payments", "status": "open"},
         {"type": "commit", "key": "abc", "text": "ignored"}]


class ProjectFactsTests(unittest.TestCase):
    """The client's words checked against Jira and GitHub, not only the meeting memory."""

    def _svc(self, rows, facts=lambda ctx, text, project: FACTS, prompts=None):
        return live.LiveSessions(FakeGraph(), model(rows, prompts=prompts), history=lambda ctx, q, p: [],
                                 open_questions=lambda ctx, p: [], facts=facts)

    def test_tickets_and_pull_requests_are_shown_with_their_status(self):
        prompts = []
        svc = self._svc([], prompts=prompts)
        svc.start(CTX, "f1", "SYNT")
        svc.assist(CTX, "f1", PART1)
        self.assertIn('T1: Jira ticket SYNT-12 [In Progress] "Pay by card"', prompts[0])
        self.assertIn('T2: pull request #45 for SYNT-12 [open] "Card payments"', prompts[0])
        self.assertNotIn("ignored", prompts[0])

    def test_a_conflict_with_a_ticket_keeps_the_ticket(self):
        rows = [{"kind": "conflict", "text": "The client says card payment is done; Jira shows SYNT-12 In Progress.",
                 "quote": "عايزين الدفع يكون بالفيزا بس.", "ref": "T1"}]
        svc = self._svc(rows)
        svc.start(CTX, "f2", "SYNT")
        found = svc.assist(CTX, "f2", PART1)["suggestions"]
        self.assertEqual(found[0]["ref"]["uid"], "SYNT-12")
        self.assertEqual(found[0]["ref"]["status"], "In Progress")

    def test_unverified_needs_the_clients_words_and_points_at_nothing(self):
        rows = [{"kind": "unverified", "text": "Nothing on record shows weekly delivery was agreed; confirm it.",
                 "quote": "عايزين الدفع يكون بالفيزا بس.", "ref": "T1"},
                {"kind": "unverified", "text": "A claim without the client's words.", "quote": None}]
        svc = self._svc(rows)
        svc.start(CTX, "f3", "SYNT")
        found = svc.assist(CTX, "f3", PART1)["suggestions"]
        self.assertEqual([f["kind"] for f in found], ["unverified"])
        self.assertIsNone(found[0]["ref"])

    def test_a_reference_the_model_made_up_is_refused(self):
        rows = [{"kind": "conflict", "text": "Conflicts with SYNT-99.", "quote": "عايزين الدفع يكون بالفيزا بس.",
                 "ref": "T9"}]
        svc = self._svc(rows)
        svc.start(CTX, "f4", "SYNT")
        self.assertEqual(svc.assist(CTX, "f4", PART1)["suggestions"], [])

    def test_no_facts_is_no_reason_to_stop_helping(self):
        def broken(ctx, text, project):
            raise RuntimeError("graph down")
        rows = [{"kind": "ask_client", "text": "Ask about refunds.", "quote": "عايزين الدفع يكون بالفيزا بس."}]
        svc = self._svc(rows, facts=broken)
        svc.start(CTX, "f5", "SYNT")
        self.assertEqual(len(svc.assist(CTX, "f5", PART1)["suggestions"]), 1)


class LiveFactsTests(unittest.TestCase):
    def test_only_this_project_and_the_pull_requests_of_its_tickets(self):
        from unittest.mock import patch
        from syntrace_ai.github import github_graph
        from syntrace_ai.meetings import meeting_notes as mn
        from syntrace_ai.graph import semantic_search
        ctx = AccessContext("acme", ("SYNT", "OTHER"), syntrace_projects=("p1",))
        seen = {}

        def search(text, scoped, min_score):
            seen["projects"] = scoped.allowed_projects
            return [{"key": "SYNT-12", "summary": "Pay by card", "status": "In Progress"},
                    {"key": "SYNT-13", "summary": None, "status": "Unknown", "incomplete": True}]

        def activity(ctx, run_query, key=None, kind=None, limit=10):
            return {"pull_requests": [{"number": 45, "title": "Card payments", "state": "closed", "merged": True}]}
        with patch.object(semantic_search, "semantic_search", search), patch.object(github_graph, "activity", activity):
            facts = mn.live_facts(ctx, "الدفع بالفيزا", "synt")
        self.assertEqual(seen["projects"], ("SYNT",))
        self.assertEqual(facts, [{"type": "ticket", "key": "SYNT-12", "text": "Pay by card", "status": "In Progress"},
                                 {"type": "pull_request", "key": "#45", "ticket": "SYNT-12", "text": "Card payments",
                                  "status": "merged"}])
        self.assertEqual(mn.live_facts(ctx, "x", "NOPE"), [])
