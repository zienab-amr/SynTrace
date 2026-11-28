"""Requirement memory against a real Neo4j: a requirement said in one meeting and updated in the next.

  $env:NEO4J_INTEGRATION="1"; python -m unittest -v test_memory_neo4j

Meetings and their approved items are written directly (no model), then the memory is applied the way
approval does. Each test uses a random company and removes everything it wrote.
"""
import os
import unittest
import uuid

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.meetings import meeting_notes as mn
from syntrace_ai.meetings import memory as rm
from syntrace_ai.graph.query_engine import AccessContext, get_driver, run_query

READY = os.getenv("NEO4J_INTEGRATION") == "1" and bool(os.getenv("NEO4J_URI"))


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1 and a running Neo4j")
class RequirementMemoryNeo4j(unittest.TestCase):
    def setUp(self):
        self.tenant = f"memtest-{uuid.uuid4().hex[:8]}"
        self.ctx = AccessContext(self.tenant, ("SYNT",))

    def tearDown(self):
        run_query("MATCH (n) WHERE n.tenant_id = $t DETACH DELETE n", t=self.tenant)

    def meeting(self, source_id, title, day, items):
        """An approved meeting with approved items: (item id, type, text, evidence, relation, earlier ids, note)."""
        uid = mn.source_uid(self.tenant, source_id)
        run_query("CREATE (s:Source {uid: $uid, tenant_id: $t, project_key: 'SYNT', source_id: $sid, title: $title, "
                  "meeting_date: $day, status: 'approved', source_type: 'online', text: ''})",
                  uid=uid, t=self.tenant, sid=source_id, title=title, day=day)
        for item_id, kind, text, evidence, relation, earlier, note in items:
            run_query("""
                MATCH (s:Source {uid: $uid})
                CREATE (i:MeetingItem {uid: $iid, tenant_id: $t, project_key: 'SYNT', source_uid: $uid, type: $kind,
                                       text: $text, evidence: $evidence, lines: [3], relation: $relation,
                                       relation_note: $note, status: 'approved'})
                MERGE (s)-[:HAS_ITEM]->(i)
                WITH i UNWIND $earlier AS e MATCH (old:MeetingItem {uid: e}) MERGE (i)-[:RELATES_TO]->(old)
                """, uid=uid, iid=f"{self.tenant}:{item_id}", t=self.tenant, kind=kind, text=text, evidence=evidence,
                      relation=relation, note=note, earlier=[f"{self.tenant}:{e}" for e in earlier])
        with get_driver().session() as session:
            session.execute_write(lambda tx: rm.apply_approved(tx, uid, self.tenant, "SYNT"))
            session.execute_write(lambda tx: rm.apply_answers(tx, uid))
        return source_id

    def story(self):
        return mn.requirement_history(self.ctx, question="login")

    def test_said_in_one_meeting_updated_in_the_next(self):
        self.meeting("m1", "Kickoff", "2026-11-05",
                     [("i1", "requirement", "Users log in with email only.", "عايزين login بالايميل بس", "new", [], None)])
        self.meeting("m2", "Sprint 1 Review", "2026-11-12",
                     [("i2", "requirement", "Users log in with email or Google.", "وكمان login بجوجل", "change", ["i1"],
                       "In Kickoff (2026-11-05) the client asked for email only; now Google too.")])
        found = self.story()
        self.assertEqual(len(found), 1)
        req = found[0]
        self.assertEqual((req["text"], req["status"]), ("Users log in with email or Google.", "active"))
        self.assertEqual([(c["type"], c["meeting"], c["meeting_date"]) for c in req["changes"]],
                         [("created", "Kickoff", "2026-11-05"), ("modified", "Sprint 1 Review", "2026-11-12")])
        self.assertEqual(req["changes"][1]["before"], "Users log in with email only.")
        context = rm.history_context(found)
        self.assertIn('Kickoff (2026-11-05): asked for "Users log in with email only."', context)
        self.assertIn('Sprint 1 Review (2026-11-12): changed it to "Users log in with email or Google."', context)

    def test_dropped_then_brought_back(self):
        self.meeting("m1", "Kickoff", "2026-11-05",
                     [("i1", "requirement", "Users log in with Google.", "login بجوجل", "new", [], None)])
        self.meeting("m2", "Scope Freeze", "2026-11-19",
                     [("i2", "decision", "Google login is removed for now.", "شيلوا جوجل", "dropped", ["i1"], None)])
        self.assertEqual(self.story()[0]["status"], "dropped")
        self.meeting("m3", "Release Planning", "2026-11-26",
                     [("i3", "requirement", "Users log in with Google again.", "رجعوا login جوجل", "existing", ["i2"], None)])
        # i3 relates to the decision i2, which is ABOUT the same requirement
        req = self.story()[0]
        self.assertEqual(req["status"], "active")
        self.assertEqual([c["type"] for c in req["changes"]], ["created", "dropped", "restored"])

    def test_deleting_the_update_meeting_replays_the_story(self):
        self.meeting("m1", "Kickoff", "2026-11-05",
                     [("i1", "requirement", "Users log in with email only.", "login بالايميل بس", "new", [], None)])
        self.meeting("m2", "Sprint 1 Review", "2026-11-12",
                     [("i2", "requirement", "Users log in with email or Google.", "وكمان login بجوجل", "change", ["i1"], None)])
        mn.delete_source(self.ctx, "m2")
        req = self.story()[0]
        self.assertEqual((req["text"], [c["type"] for c in req["changes"]]), ("Users log in with email only.", ["created"]))

    def test_deleting_the_only_meeting_deletes_the_requirement(self):
        self.meeting("m1", "Kickoff", "2026-11-05",
                     [("i1", "requirement", "Users log in with email only.", "login بالايميل بس", "new", [], None)])
        mn.delete_source(self.ctx, "m1")
        self.assertEqual(self.story(), [])
        self.assertEqual(run_query("MATCH (n:Change {tenant_id: $t}) RETURN count(n) AS n", t=self.tenant)[0]["n"], 0)

    def test_a_team_member_edits_the_wording(self):
        self.meeting("m1", "Kickoff", "2026-11-05",
                     [("i1", "requirement", "Users log in with email only.", "login بالايميل بس", "new", [], None)])
        req_uid = self.story()[0]["uid"]
        after = mn.edit_requirement(self.ctx, req_uid, "Users sign in with their email address.", "emp-7")
        self.assertEqual(after[0]["text"], "Users sign in with their email address.")
        self.assertEqual([(c["type"], c.get("by")) for c in after[0]["changes"]][-1], ("edited", "emp-7"))

    def test_another_company_sees_nothing(self):
        self.meeting("m1", "Kickoff", "2026-11-05",
                     [("i1", "requirement", "Users log in with email only.", "login بالايميل بس", "new", [], None)])
        other = AccessContext(f"other-{uuid.uuid4().hex[:6]}", ("SYNT",))
        self.assertEqual(mn.requirement_history(other, question="login"), [])
        self.assertEqual(mn.requirement_history(AccessContext(self.tenant, ("OTHER",)), question="login"), [])


    def test_an_earlier_decision_becomes_the_start_of_the_story(self):
        self.meeting("m1", "Release planning", "2026-11-01",
                     [("d1", "decision", "Release notes are in English only.", "الـ release notes هتكون English بس",
                       "new", [], None)])
        self.assertEqual(mn.requirement_history(self.ctx, question="release notes"), [])   # a decision alone
        self.meeting("m2", "Client sync", "2026-11-20",
                     [("r2", "requirement", "Release notes must be in Arabic only.", "الـ release notes لازم تبقى بالعربي بس",
                       "conflict", ["d1"], "In Release planning (2026-11-01) English only; now Arabic only.")])
        req = mn.requirement_history(self.ctx, question="release notes")[0]
        self.assertEqual([(c["type"], c["meeting"]) for c in req["changes"]],
                         [("created", "Release planning"), ("modified", "Client sync")])
        self.assertEqual(req["text"], "Release notes must be in Arabic only.")

    def test_an_open_question_answered_in_a_later_meeting(self):
        self.meeting("m1", "Kickoff", "2026-11-05",
                     [("q1", "open_question", "Arabic only or Arabic and English?", "عربي بس ولا الاتنين؟ لسه بنفكر",
                       "new", [], None)])
        self.assertEqual([q["text"] for q in mn.open_questions(self.ctx, "SYNT")], ["Arabic only or Arabic and English?"])
        self.meeting("m2", "Sprint 1 Review", "2026-11-12",
                     [("a1", "decision", "The app supports Arabic and English.", "خلاص الاتنين عربي وانجليزي", "answers",
                       ["q1"], "Kickoff asked Arabic only or both; now both.")])
        self.assertEqual(mn.open_questions(self.ctx, "SYNT"), [])
        mn.delete_source(self.ctx, "m2")   # the answer goes with its meeting: the question is open again
        self.assertEqual(len(mn.open_questions(self.ctx, "SYNT")), 1)


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1 and a running Neo4j")
class LiveSessionNeo4j(unittest.TestCase):
    """The live session's real Cypher: start, assist twice (only new help), end with the next meeting's list."""
    def setUp(self):
        self.tenant = f"livetest-{uuid.uuid4().hex[:8]}"
        self.ctx = AccessContext(self.tenant, ("SYNT",))
        self.addCleanup(lambda: run_query("MATCH (n) WHERE n.tenant_id = $t DETACH DELETE n", t=self.tenant))

    def test_a_live_session_end_to_end(self):
        import json
        reply = json.dumps({"suggestions": [{"kind": "ask_client", "text": "Ask whether cash is needed too.",
                                             "quote": "الدفع بالفيزا بس"}], "answer": None})
        live = mn.live_sessions(llm=lambda prompt: reply)
        live.start(self.ctx, "s1", "SYNT", "Client sync")
        text = "Sara Client: أهلًا.\nSara Client: الدفع بالفيزا بس."
        first = live.assist(self.ctx, "s1", text)
        self.assertEqual(len(first["suggestions"]), 1)
        self.assertEqual(live.assist(self.ctx, "s1", text + "\nSara Client: تمام.")["suggestions"], [])
        view = live.view(self.ctx, "s1")
        # the last line may still be being spoken: it is read, but counted as seen only once a line follows it
        self.assertEqual((view["lines_seen"], len(view["suggestions"])), (2, 1))
        ended = live.end(self.ctx, "s1")
        self.assertEqual(ended["next_meeting"]["not_asked"][0]["text"], "Ask whether cash is needed too.")
        with self.assertRaises(mn.MeetingError):
            live.view(AccessContext("someone-else", ("SYNT",)), "s1")


if __name__ == "__main__":
    unittest.main()


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1 and a running Neo4j")
class DocumentNeo4j(unittest.TestCase):
    """SYNT-907: the edited notes go back to the items in the graph."""

    def setUp(self):
        self.tenant = f"doctest-{uuid.uuid4().hex[:8]}"
        self.ctx = AccessContext(self.tenant, ("SYNT",))
        uid = mn.source_uid(self.tenant, "d1")
        run_query("CREATE (s:Source {uid: $uid, tenant_id: $t, project_key: 'SYNT', source_id: 'd1', title: 'Sync', "
                  "meeting_date: '2026-11-20', status: 'pending_review', source_type: 'online', text: 'x', "
                  "summary: 'Kickoff.'})", uid=uid, t=self.tenant)
        for iid, kind, text, owner in (("a", "requirement", "Users log in with email.", None),
                                       ("b", "decision", "Role permissions are handled by the backend.", None),
                                       ("c", "action_item", "Send the design.", "Fatma")):
            run_query("MATCH (s:Source {uid: $uid}) CREATE (i:MeetingItem {uid: $iid, tenant_id: $t, project_key: 'SYNT', "
                      "source_uid: $uid, type: $kind, text: $text, evidence: 'quote', lines: [1], owner: $owner, "
                      "status: 'pending', needs_review: false}) MERGE (s)-[:HAS_ITEM]->(i)",
                      uid=uid, iid=f"{uid}:item:{iid}", t=self.tenant, kind=kind, text=text, owner=owner)

    def tearDown(self):
        run_query("MATCH (n) WHERE n.tenant_id = $t DETACH DELETE n", t=self.tenant)

    def test_edits_change_add_and_remove_items(self):
        text = mn.document(self.ctx, "d1")["text"]
        edited = (text.replace("Users log in with email.", "Users log in with email or phone.")
                      .replace("owner: Fatma", "owner: Rodaina")
                      .replace("Decisions\n- Role permissions are handled by the backend.\n", "")
                  + "\nBlockers\n- The server is down.")
        view = mn.edit_document(self.ctx, "d1", edited, editor="fatma")
        self.assertEqual(view["changes"], {"changed": 2, "added": 1, "removed": 1})
        items = {i["text"]: i for i in view["items"]}
        self.assertIn("Users log in with email or phone.", items)
        self.assertEqual(items["Send the design."]["owner"], "Rodaina")
        self.assertNotIn("Role permissions are handled by the backend.", items)
        self.assertEqual(items["The server is down."]["added_by"], "fatma")
        self.assertIsNone(items["The server is down."]["evidence"])
        self.assertEqual(mn.document(self.ctx, "d1")["text"], edited)
        self.assertEqual(mn.document(self.ctx, "d1")["editedBy"], "fatma")
