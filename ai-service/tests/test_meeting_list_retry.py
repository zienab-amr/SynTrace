"""The project's meetings list and retrying a failed meeting (API contract; the graph is replaced)."""
import os
import unittest
from unittest.mock import patch

from syntrace_ai.graph.query_engine import AccessContext
from syntrace_ai.meetings import meeting_notes as mn

VIEW = {"source": {"source_id": "m1", "source_type": "offline", "title": "Sync", "meeting_date": "2026-11-27",
                   "status": "processing", "project_key": "SYNT", "rejected_items": 0, "scope": {}},
        "items": []}


class ListSourcesTests(unittest.TestCase):
    def test_outside_the_allowed_projects_is_403(self):
        with self.assertRaises(mn.MeetingError) as caught:
            mn.list_sources(AccessContext("acme", ("SYNT",)), "OTHER")
        self.assertEqual(caught.exception.status, 403)

    def test_an_unknown_status_is_400(self):
        with self.assertRaises(mn.MeetingError) as caught:
            mn.list_sources(AccessContext("acme", ("SYNT",)), "synt", status="done")
        self.assertEqual(caught.exception.status, 400)

    def test_the_project_key_is_uppercased_and_the_limit_bounded(self):
        with patch.object(mn, "run_query", return_value=[]) as query:
            mn.list_sources(AccessContext("acme", ("SYNT",)), " synt ", limit=10_000)
        kwargs = query.call_args.kwargs
        self.assertEqual((kwargs["project"], kwargs["tenant"], kwargs["limit"]), ("SYNT", "acme", 500))
        self.assertNotIn(".text", query.call_args.args[0])   # the list never carries the transcript


class ApiTests(unittest.TestCase):
    def setUp(self):
        from fastapi.testclient import TestClient
        from syntrace_ai.api import ai_service
        env = patch.dict(os.environ, {"AI_API_KEY": "list-key"})
        env.start()
        self.addCleanup(env.stop)
        self.client, self.headers = TestClient(ai_service.app), {"X-Internal-Api-Key": "list-key"}
        self.who = {"companyId": "acme", "allowedProjects": ["SYNT"]}

    def test_list_is_camel_case(self):
        rows = [{"source_id": "m1", "source_type": "pdf", "title": "Kickoff", "meeting_date": "2026-11-20",
                 "status": "approved", "project_key": "SYNT", "error": None, "linked_source_id": None,
                 "created_at": "2026-11-20T10:00:00+00:00", "created_by": "e1", "items": 7, "to_review": 0}]
        with patch.object(mn, "list_sources", return_value=rows) as listed:
            r = self.client.get("/projects/SYNT/meetings?companyId=acme&allowedProjects=SYNT&status=approved",
                                headers=self.headers)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(listed.call_args.args[1:], ("SYNT", "approved"))
        meeting = r.json()["meetings"][0]
        self.assertEqual((meeting["sourceId"], meeting["items"], meeting["toReview"], meeting["createdBy"]),
                         ("m1", 7, 0, "e1"))

    def test_list_needs_the_key(self):
        r = self.client.get("/projects/SYNT/meetings?companyId=acme&allowedProjects=SYNT")
        self.assertEqual(r.status_code, 401)

    def test_retry_returns_the_processing_view(self):
        with patch.object(mn, "retry_source", return_value=VIEW) as retried:
            r = self.client.post("/meetings/m1/retry", json=self.who, headers=self.headers)
        self.assertEqual(r.status_code, 202)
        self.assertEqual(r.json()["status"], "processing")
        self.assertEqual(retried.call_args.args[1], "m1")

    def test_retry_of_a_meeting_that_did_not_fail_is_409(self):
        with patch.object(mn, "retry_source", side_effect=mn.MeetingError("only a failed source can be retried", 409)):
            r = self.client.post("/meetings/m1/retry", json=self.who, headers=self.headers)
        self.assertEqual(r.status_code, 409)


if __name__ == "__main__":
    unittest.main()
