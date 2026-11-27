"""The chat as a way into live meeting help (meetings/chat_meeting.py), with a fake store and live helper."""
import unittest

from syntrace_ai.meetings import chat_meeting as cm
from syntrace_ai.graph.query_engine import AccessContext

CTX = AccessContext("acme", ("DEL", "HR"))
PROJECTS = {"DEL": "Delivery App", "HR": "HR Portal"}


class FakeStore:
    def __init__(self):
        self.rows = {}

    def __call__(self, query, **p):
        if query.startswith("MATCH (c:ChatMeeting"):
            c = self.rows.get(p["uid"])
            return [{"c": dict(c)}] if c else []
        if query.startswith("MERGE (c:ChatMeeting"):
            self.rows.setdefault(p["uid"], {"uid": p["uid"]}).update(p["fields"])
            return []
        raise AssertionError(query)


class FakeLive:
    def __init__(self):
        self.calls = []

    def start(self, ctx, sid, project, title=None, started_by=None):
        self.calls.append(("start", sid, project))

    def assist(self, ctx, sid, transcript, question=None):
        self.calls.append(("assist", sid, transcript, question))
        return {"suggestions": [{"kind": "unverified", "text": "Weekly delivery is not on record; confirm it.",
                                 "ref": None}], "answer": None, "lines_seen": 1}

    def wrap_up(self, ctx, sid, transcript):
        self.calls.append(("wrap_up", sid))
        return {"suggestions": [{"kind": "missing", "text": "Ask who can see the reports."}]}

    def end(self, ctx, sid, transcript, meeting_date, created_by):
        self.calls.append(("end", sid, transcript))
        return {"source_id": f"live-{sid}"}


def chats(projects=PROJECTS):
    live = FakeLive()
    return cm.ChatMeetings(FakeStore(), live, lambda ctx: projects,
                           lambda ctx, p: [{"text": "Which payment methods?", "meeting": "Kickoff", "date": "2026-11-05"}]), live


class ChatMeetingTests(unittest.TestCase):
    def test_a_normal_question_is_left_to_the_chat(self):
        c, live = chats()
        self.assertIsNone(c.handle(CTX, "u1", "conv", "What is the status of DEL-12?"))
        self.assertEqual(live.calls, [])

    def test_an_unclear_project_gets_one_question_and_the_part_is_kept(self):
        c, live = chats()
        asked = c.handle(CTX, "u1", "conv", "عندي meeting مع العميل دلوقتي", "Client: we need weekly delivery")
        self.assertTrue(asked["meeting"]["needsProject"])
        self.assertIn("Delivery App", asked["answer"])
        self.assertEqual(live.calls, [])
        helped = c.handle(CTX, "u1", "conv", "Delivery App")
        self.assertEqual(helped["meeting"]["project"], "DEL")
        self.assertEqual(live.calls[0][0], "start")
        self.assertEqual(live.calls[1][2], "Client: we need weekly delivery")   # the kept part is read now
        self.assertIn("مش متسجّل", helped["answer"])   # the language of the first message

    def test_a_named_project_starts_at_once_with_its_open_questions(self):
        c, live = chats()
        hi = c.handle(CTX, "u1", "conv", "We have another meeting on DEL today")
        self.assertEqual(hi["meeting"]["project"], "DEL")
        self.assertIn("Which payment methods?", hi["answer"])

    def test_parts_add_up_once_and_a_question_mid_meeting_goes_to_the_chat(self):
        c, live = chats()
        c.handle(CTX, "u1", "conv", "meeting on DEL")
        c.handle(CTX, "u1", "conv", "part one", "Client: hello")
        c.handle(CTX, "u1", "conv", "part one again", "Client: hello")
        c.handle(CTX, "u1", "conv", "part two", "Client: we need reports")
        assists = [call for call in live.calls if call[0] == "assist"]
        self.assertEqual(assists[-1][2], "Client: hello\nClient: we need reports")
        self.assertIsNone(c.handle(CTX, "u1", "conv", "How many open bugs does DEL have?"))

    def test_done_wraps_up_ends_and_sends_to_review(self):
        c, live = chats()
        c.handle(CTX, "u1", "conv", "meeting on DEL", "Client: hello")
        done = c.handle(CTX, "u1", "conv", "خلصنا")
        self.assertEqual([k[0] for k in live.calls][-2:], ["wrap_up", "end"])
        self.assertTrue(done["meeting"]["ended"])
        self.assertIn("Ask who can see the reports.", done["answer"])
        self.assertIn("للمراجعة", done["answer"])
        again = c.handle(CTX, "u1", "conv", "another meeting on DEL")   # a new meeting: a new live session
        self.assertNotEqual(again["meeting"]["sessionId"], done["meeting"]["sessionId"])

    def test_one_project_is_taken_without_asking(self):
        c, live = chats({"DEL": "Delivery App"})
        r = c.handle(AccessContext("acme", ("DEL",)), "u1", "conv", "meeting now", "Client: hi")
        self.assertEqual(r["meeting"]["project"], "DEL")

    def test_a_new_project_asks_which_one_and_says_to_create_it_first(self):
        c, live = chats({"DEL": "Delivery App"})
        r = c.handle(AccessContext("acme", ("DEL",)), "u1", "conv", "عندي meeting على project جديد")
        self.assertTrue(r["meeting"]["needsProject"])
        self.assertIn("SynTrace", r["answer"])

    def test_people_and_chats_do_not_share_a_meeting(self):
        self.assertNotEqual(cm.chat_uid("acme", "u1", "conv"), cm.chat_uid("acme", "u2", "conv"))
        self.assertNotEqual(cm.chat_uid("acme", "u1", "conv"), cm.chat_uid("other", "u1", "conv"))


class AskApiTests(unittest.TestCase):
    """/ask with a pasted transcript: the meeting answer, and the usual contract otherwise."""

    def setUp(self):
        import os
        from unittest.mock import patch
        from fastapi.testclient import TestClient
        from syntrace_ai.api import ai_service
        from syntrace_ai.meetings import meeting_notes
        self.client, self.headers = TestClient(ai_service.app), {"X-Internal-Api-Key": "chat-meeting-key"}
        c, self.live = chats()
        for target in (patch.dict(os.environ, {"AI_API_KEY": "chat-meeting-key"}),
                       patch.object(meeting_notes, "chat_meetings", return_value=c),
                       patch.object(meeting_notes, "meeting_ctx", side_effect=lambda ctx: ctx)):
            target.start()
            self.addCleanup(target.stop)
        self.body = {"companyId": "acme", "employeeId": "u1", "allowedProjects": ["DEL", "HR"],
                     "conversationId": "conv", "permissions": {"canUseMeetingAgent": True}}

    def test_a_pasted_part_gets_live_help(self):
        r = self.client.post("/ask", headers=self.headers,
                             json={**self.body, "question": "meeting on DEL", "transcript": "Client: weekly delivery"})
        self.assertEqual(r.status_code, 200)
        data = r.json()
        self.assertEqual(data["source"], "meeting")
        self.assertEqual(data["meeting"]["project"], "DEL")
        self.assertEqual(data["meeting"]["suggestions"][0]["kind"], "unverified")

    def test_a_user_the_company_does_not_allow_gets_no_meeting_help(self):
        body = dict(self.body)
        del body["permissions"]   # not sent: not allowed
        r = self.client.post("/ask", headers=self.headers,
                             json={**body, "question": "meeting on DEL", "transcript": "Client: hi"}).json()
        self.assertIn("not available to your account", r["answer"])
        self.assertEqual(self.live.calls, [])

    def test_an_unclear_project_asks(self):
        r = self.client.post("/ask", headers=self.headers,
                             json={**self.body, "question": "عندي meeting", "transcript": "Client: hi"}).json()
        self.assertTrue(r["meeting"]["needsProject"])


if __name__ == "__main__":
    unittest.main()
