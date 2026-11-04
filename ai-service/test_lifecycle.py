"""Focused offline tests for stable Jira identity and deletion lifecycle behavior."""
import os
import unittest
from unittest.mock import patch

os.environ.setdefault("JIRA_SITE_ID", "syntrace.atlassian.net")

import ingest
import query_engine as qe


class Result:
    def __init__(self, rows=()):
        self.rows = list(rows)

    def single(self):
        return self.rows[0] if self.rows else None

    def __iter__(self):
        return iter(self.rows)


class LifecycleTx:
    """Small transaction fake for deterministic lifecycle/Cypher routing tests."""
    def __init__(self, nodes=()):
        self.nodes = {n["key"]: dict(n) for n in nodes}
        self.calls = []
        self.deleted = []

    def run(self, query, **params):
        q = " ".join(query.split())
        self.calls.append((q, params))
        if "RETURN w.uid AS uid, w.key AS key, w.jira_id AS jira_id" in q:
            key, site = params.get("key"), params.get("site")
            rows = []
            for node in self.nodes.values():
                aliases = node.get("key_aliases") or []
                if node.get("site_id") not in (None, site):
                    continue
                if key == node["key"] or key in aliases:
                    rows.append({"uid": node["uid"], "key": node["key"],
                                 "jira_id": node.get("jira_id"), "site_id": node.get("site_id"),
                                 "issuetype": node.get("issuetype"), "key_aliases": aliases})
            return Result(rows)
        if "RETURN s.key AS k" in q:
            parent = params.get("key")
            return Result([{"k": n["key"]} for n in self.nodes.values()
                           if n.get("parent") == parent])
        if "RETURN w.key AS key" in q and "project_key: $key" in q:
            return Result([{"key": n["key"]} for n in self.nodes.values()
                           if n.get("site_id") == params.get("site")
                           and n.get("project_key") == params.get("key")])
        if "DETACH DELETE w" in q and params.get("uid"):
            uid = params["uid"]
            for key, node in list(self.nodes.items()):
                if node["uid"] == uid:
                    self.deleted.append(key)
                    del self.nodes[key]
        return Result()


def issue(key="NEW-1", jira_id="42", host="syntrace.atlassian.net", project=None, **fields):
    project = project or key.split("-")[0]
    return {"id": str(jira_id), "key": key,
            "self": f"https://{host}/rest/api/3/issue/{jira_id}",
            "fields": {"project": {"key": project, "self": f"https://{host}/rest/api/3/project/1"}, **fields}}


class StableIdentityTests(unittest.TestCase):
    def test_identity_is_stable_and_scoped_by_tenant_and_site(self):
        with patch.dict(os.environ, {"JIRA_SITE_ID": ""}):
            a = ingest.normalize_issue(issue(), "tenant-a")
            moved = ingest.normalize_issue(issue("NEXT-9", "42", project="NEXT"), "tenant-a")
            other_site = ingest.normalize_issue(issue(host="another.atlassian.net"), "tenant-a")
            other_tenant = ingest.normalize_issue(issue(), "tenant-b")
        self.assertEqual(a["uid"], moved["uid"])
        self.assertNotEqual(a["uid"], other_site["uid"])
        self.assertNotEqual(a["uid"], other_tenant["uid"])
        self.assertEqual(moved["props"]["project_key"], "NEXT")

    def test_partial_payload_does_not_clear_omissions_but_explicit_null_does(self):
        partial = ingest.normalize_issue(issue(), "t")
        # Summary is absent: partial payload must leave it untouched.
        self.assertNotIn("summary", partial["props"])
        self.assertNotIn("summary", partial["clear_props"])
        explicit = ingest.normalize_issue(issue("NEW-1", summary=None, assignee=None,
                                                parent=None, issuelinks=None), "t")
        self.assertIn("summary", explicit["clear_props"])
        self.assertIsNone(explicit["assignee"])
        self.assertIsNone(explicit["parent"])
        self.assertEqual(explicit["links"], [])

    def test_full_snapshot_clears_omitted_state(self):
        model = ingest.normalize_issue(issue(), "t", payload_mode="full")
        self.assertIn("summary", model["clear_props"])
        self.assertIn("priority", model["clear_props"])
        self.assertEqual(model["subtasks"], [])
        self.assertEqual(model["links"], [])
        self.assertIsNone(model["parent"])
        self.assertIsNone(model["assignee"])

    def test_explicit_null_uses_whitelisted_property_removal(self):
        model = ingest.normalize_issue(issue(summary=None), "t")
        tx = LifecycleTx()
        ingest.write_issue_state(tx, model)
        self.assertTrue(any("REMOVE w.summary" in q for q, _ in tx.calls))

    def test_stale_or_unordered_updates_never_overwrite_known_state(self):
        self.assertTrue(ingest.is_stale("2026-10-27T11:00:00+00:00", None))
        self.assertTrue(ingest.is_stale(None, None))
        self.assertFalse(ingest.is_stale(None, "2026-10-27T11:00:00+00:00"))
        self.assertTrue(ingest.is_stale("2026-10-27T11:00:00+00:00",
                                        "2026-10-27T10:59:59+00:00"))

    def test_deleted_issue_is_stored_again_when_it_comes_back(self):
        tx = LifecycleTx()
        self.assertEqual(ingest.upsert_issue(tx, issue(), "t"), "upserted")
        self.assertTrue(any("MERGE (w:WorkItem" in q for q, _ in tx.calls))
        self.assertFalse(any("Tombstone" in q for q, _ in tx.calls))

    def test_aliases_are_retained_by_state_upsert_query(self):
        tx = LifecycleTx()
        model = ingest.normalize_issue(issue("NEXT-9", "42", project="NEXT"), "t")
        ingest.write_issue_state(tx, model)
        q = next(q for q, _ in tx.calls if "prior_key" in q)
        self.assertIn("coalesce(w.key_aliases, []) + [prior_key, $props.key]", q)
        self.assertNotIn("key_aliases", model["props"])

    def test_authorized_old_project_alias_resolves_without_bypassing_project_scope(self):
        ctx = qe.AccessContext("t", ("NEXT",))
        calls = []

        def fake_query(query, **params):
            calls.append((query, params))
            if "requested IN coalesce(w.key_aliases" in query:
                return [{"key": "OLD-1"}]
            return [{"key": "NEXT-9", "summary": "Moved item", "status": "To Do",
                     "category": "new", "priority": "Low", "issuetype": "Task",
                     "project": "NEXT", "url": "https://x/browse/NEXT-9", "assignee": None,
                     "parent": None, "sprints": []}]

        with patch.object(qe, "run_query", fake_query):
            result = qe.answer_key_question("What is OLD-1?", ctx)
        self.assertEqual(result[0]["type"], "found")
        self.assertTrue(any("w.project_key IN $allowed" in q for q, _ in calls))
        self.assertEqual(calls[0][1]["allowed"], ["NEXT"])


class LifecycleTests(unittest.TestCase):
    def test_deleted_epic_preserves_child_stories(self):
        tx = LifecycleTx(nodes=[{"uid": "u:epic", "key": "PROJ-1", "jira_id": "1",
                                 "site_id": "syntrace.atlassian.net", "issuetype": "Epic"},
                                {"uid": "u:story", "key": "PROJ-2", "jira_id": "2",
                                 "site_id": "syntrace.atlassian.net", "issuetype": "Story", "parent": "PROJ-1"}])
        self.assertEqual(ingest.delete_issue(tx, "PROJ-1", "t", site_id="syntrace.atlassian.net"), "deleted")
        self.assertIn("PROJ-2", tx.nodes)
        self.assertNotIn("PROJ-1", tx.nodes)
        self.assertFalse(any("RETURN s.key AS k" in q for q, _ in tx.calls))

    def test_non_epic_recursively_deletes_nested_descendants(self):
        tx = LifecycleTx(nodes=[
            {"uid": "u:root", "key": "P-1", "jira_id": "1", "site_id": "syntrace.atlassian.net", "issuetype": "Story"},
            {"uid": "u:child", "key": "P-2", "jira_id": "2", "site_id": "syntrace.atlassian.net", "issuetype": "Task", "parent": "P-1"},
            {"uid": "u:leaf", "key": "P-3", "jira_id": "3", "site_id": "syntrace.atlassian.net", "issuetype": "Subtask", "parent": "P-2"},
        ])
        ingest.delete_issue(tx, "P-1", "t", site_id="syntrace.atlassian.net")
        self.assertEqual(set(tx.deleted), {"P-1", "P-2", "P-3"})
        self.assertFalse(tx.nodes)
        evidence_queries = [q for q, _ in tx.calls if "r.evidence" in q]
        self.assertEqual(len(evidence_queries), 3)
        self.assertIn("size(r.evidence) = 0", evidence_queries[0])
        self.assertIn("size(r.source_issue_uids) = 0", evidence_queries[0])

    def test_deletion_by_old_key_removes_the_node_and_leaves_no_trace(self):
        tx = LifecycleTx(nodes=[{"uid": "stable", "key": "NEW-1", "jira_id": "42",
                                 "site_id": "syntrace.atlassian.net", "issuetype": "Task",
                                 "key_aliases": ["OLD-1"]}])
        ingest.delete_issue(tx, "OLD-1", "t", site_id="syntrace.atlassian.net")
        self.assertEqual(tx.nodes, {})
        self.assertFalse(any("Tombstone" in q for q, _ in tx.calls))

    def test_issue_deletion_cleans_orphaned_events_by_alias_and_issue_id(self):
        tx = LifecycleTx(nodes=[{"uid": "stable", "key": "NEW-1", "jira_id": "42",
                                 "site_id": "syntrace.atlassian.net", "issuetype": "Task",
                                 "key_aliases": ["OLD-1"]}])
        ingest.delete_issue(tx, "OLD-1", "t", site_id="syntrace.atlassian.net")
        call = next((params for q, params in tx.calls if "o.issue_key IN $keys" in q), None)
        self.assertIsNotNone(call)
        self.assertEqual(call["keys"], ["NEW-1", "OLD-1"])
        self.assertEqual(call["jira_id"], "42")

    def test_project_delete_is_source_wide_and_does_not_touch_other_project(self):
        site = "syntrace.atlassian.net"
        tx = LifecycleTx(nodes=[
            {"uid": "p1", "key": "P-1", "jira_id": "1", "site_id": site,
             "project_key": "P", "issuetype": "Task"},
            {"uid": "p2", "key": "P-2", "jira_id": "2", "site_id": site,
             "project_key": "P", "issuetype": "Story"},
            {"uid": "q1", "key": "Q-1", "jira_id": "3", "site_id": site,
             "project_key": "Q", "issuetype": "Task"},
        ])
        count = ingest.delete_project(tx, "P", "t", site_id=site)
        self.assertEqual(count, 2)
        self.assertEqual(set(tx.nodes), {"Q-1"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
