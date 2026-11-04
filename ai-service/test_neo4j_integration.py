"""Opt-in integration tests; set NEO4J_INTEGRATION=1 and NEO4J_* to run against Neo4j.

All tests use random temporary IDs and explicitly roll back their write transaction.
"""
import os
import unittest
import uuid

from dotenv import load_dotenv

import ingest

load_dotenv()


READY = (os.getenv("NEO4J_INTEGRATION") == "1" and bool(os.getenv("NEO4J_URI")))


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1 and an available Neo4j database")
class Neo4jLifecycleIntegrationTests(unittest.TestCase):
    def setUp(self):
        from neo4j import GraphDatabase
        self.driver = GraphDatabase.driver(
            os.getenv("NEO4J_URI"),
            auth=(os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASSWORD")))
        self.session = self.driver.session()
        self.tx = self.session.begin_transaction()
        self.tenant = "integration-" + uuid.uuid4().hex
        self.site = "integration.example.invalid"

    def tearDown(self):
        self.tx.rollback()
        self.tx.close()
        self.session.close()
        self.driver.close()

    def test_legacy_rename_preserves_existing_relationship(self):
        key = "OLD-" + uuid.uuid4().hex[:8].upper()
        new_key = "NEW-" + uuid.uuid4().hex[:8].upper()
        jira_id = uuid.uuid4().hex
        legacy_uid = f"{self.tenant}:{key}"
        related_uid = f"{self.tenant}:related:{uuid.uuid4().hex}"
        stub_uid = f"{self.tenant}:site:{self.site}:stub:{new_key}"
        stable_uid = ingest.workitem_uid(self.tenant, self.site, jira_id)
        self.tx.run("CREATE (w:WorkItem {uid:$legacy, key:$key, tenant_id:$tenant, "
                     "jira_id:$jira_id, summary:'legacy'}) "
                     "CREATE (r:WorkItem {uid:$related, tenant_id:$tenant, jira_site_id:$site}) "
                     "CREATE (s:WorkItem {uid:$stub, key:$new_key, tenant_id:$tenant, "
                     "jira_site_id:$site, project_key:'NEW'}) "
                     "CREATE (w)-[:RELATES_TO]->(r) "
                     "CREATE (s)-[:AI_LINK {evidence:['source-evidence']}]->(r)",
                     legacy=legacy_uid, key=key, tenant=self.tenant,
                     jira_id=jira_id, related=related_uid, site=self.site,
                     stub=stub_uid, new_key=new_key)
        model = ingest.normalize_issue(
            {"id": jira_id, "key": new_key,
             "self": f"https://{self.site}/rest/api/3/issue/{jira_id}",
             "fields": {"summary": "updated", "project": {"key": "NEW"}}},
            self.tenant, payload_mode="partial", site_id=self.site)
        ingest.adopt_workitem_identity(self.tx, model)
        ingest.write_issue_state(self.tx, model)
        record = self.tx.run(
            "MATCH (w:WorkItem {uid:$uid})-[edge:AI_LINK]->(r {uid:$related}) "
            "RETURN w.key AS key, w.key_aliases AS aliases, w.jira_site_id AS site, "
            "edge.evidence AS evidence", uid=stable_uid, related=related_uid).single()
        self.assertEqual(record["key"], new_key)
        self.assertIn(key, record["aliases"])
        self.assertEqual(record["site"], self.site)
        self.assertEqual(record["evidence"], ["source-evidence"])
        self.assertIsNone(self.tx.run("MATCH (s:WorkItem {uid:$uid}) RETURN s.uid AS uid",
                                      uid=stub_uid).single())

    def test_evidence_cleanup_removes_only_deleted_source(self):
        rel_uid = uuid.uuid4().hex
        self.tx.run("CREATE (a:WorkItem {uid:$a, tenant_id:$tenant}) "
                    "CREATE (b:WorkItem {uid:$b, tenant_id:$tenant}) "
                    "CREATE (a)-[:AI_LINK {evidence:[$source,'other']}]->(b)",
                    a=self.tenant + ":a", b=self.tenant + ":b", tenant=self.tenant,
                    source=rel_uid)
        ingest._remove_evidence_for_source(self.tx, rel_uid, "OLD-1")
        remaining = self.tx.run(
            "MATCH (:WorkItem {uid:$a})-[r:AI_LINK]->(:WorkItem {uid:$b}) "
            "RETURN r.evidence AS evidence", a=self.tenant + ":a", b=self.tenant + ":b").single()
        self.assertEqual(remaining["evidence"], ["other"])
        ingest._remove_evidence_for_source(self.tx, "other", "OLD-1")
        count = self.tx.run(
            "MATCH (:WorkItem {uid:$a})-[r:AI_LINK]->(:WorkItem {uid:$b}) "
            "RETURN count(r) AS n", a=self.tenant + ":a", b=self.tenant + ":b").single()["n"]
        self.assertEqual(count, 0)

    def _two_issues(self):
        ids = [uuid.uuid4().hex, uuid.uuid4().hex]
        keys = ["LNK-" + uuid.uuid4().hex[:8].upper() for _ in ids]
        for jid, key in zip(ids, keys):
            item = {"id": jid, "key": key, "self": f"https://{self.site}/rest/api/3/issue/{jid}",
                    "fields": {"project": {"key": "LNK"}, "summary": key, "issuetype": {"name": "Task"},
                               "updated": "2026-10-27T10:00:00.000+0000"}}
            self.assertEqual(ingest.upsert_issue(self.tx, item, self.tenant, site_id=self.site,
                                                 payload_mode="full"), "upserted")
        return ids, keys

    def test_worklogs_are_totalled_per_person(self):
        import query_engine as qe
        from unittest.mock import patch
        jid, key = uuid.uuid4().hex, "LOG-" + uuid.uuid4().hex[:8].upper()
        person = {"accountId": uuid.uuid4().hex, "displayName": "Amr"}
        logs = [{"id": uuid.uuid4().hex, "issueId": jid, "author": person, "timeSpentSeconds": s,
                 "started": "2026-10-27T10:00:00.000+0000", "updated": "2026-10-27T10:00:00.000+0000"}
                for s in (3600, 1800)]
        item = {"id": jid, "key": key, "self": f"https://{self.site}/rest/api/3/issue/{jid}",
                "fields": {"project": {"key": "LOG"}, "summary": key, "issuetype": {"name": "Task"},
                           "updated": "2026-10-27T10:00:00.000+0000",
                           "worklog": {"worklogs": logs, "total": 2}}}
        self.assertEqual(ingest.upsert_issue(self.tx, item, self.tenant, site_id=self.site,
                                             payload_mode="full"), "upserted")
        ctx = qe.AccessContext(self.tenant, ("LOG",))
        with patch.object(qe, "run_query", lambda q, **p: list(self.tx.run(q, **p))):
            self.assertEqual(qe.get_worklogs(key, ctx), [{"author": "Amr", "seconds": 5400, "entries": 2}])

    def test_attachment_event_writes_and_deletes(self):
        (jid, _), _ = self._two_issues()
        attachment = {"id": uuid.uuid4().hex, "filename": "a.png", "mimeType": "image/png", "size": 1,
                      "created": "2026-10-27T10:00:00.000+0000", "author": {"accountId": "a", "displayName": "A"}}
        self.assertTrue(ingest.upsert_attachment(self.tx, attachment, self.tenant, self.site, issue_id=jid))
        count = lambda: self.tx.run("MATCH (:WorkItem {tenant_id:$t})-[:HAS_ATTACHMENT]->(a:Attachment) "
                                    "RETURN count(a) AS n", t=self.tenant).single()["n"]
        self.assertEqual(count(), 1)
        ingest.delete_by_uid(self.tx, "Attachment", f"{self.tenant}:site:{self.site}:attachment:{attachment['id']}")
        self.assertEqual(count(), 0)
        self.assertFalse(ingest.upsert_attachment(self.tx, attachment, self.tenant, self.site, issue_id="missing"))

    def test_issue_link_event_creates_and_removes_the_edge(self):
        (a, b), _ = self._two_issues()
        link = {"id": "1", "sourceIssueId": a, "destinationIssueId": b,
                "issueLinkType": {"name": "Blocks", "outwardName": "blocks", "inwardName": "is blocked by"}}
        count = lambda: self.tx.run("MATCH (x:WorkItem {tenant_id:$t, jira_id:$a})-[r:BLOCKS]->(y:WorkItem {jira_id:$b}) "
                                    "RETURN count(r) AS n", t=self.tenant, a=a, b=b).single()["n"]
        self.assertTrue(ingest.apply_issue_link(self.tx, link, self.tenant, self.site))
        self.assertEqual(count(), 1)
        self.assertTrue(ingest.apply_issue_link(self.tx, link, self.tenant, self.site, remove=True))
        self.assertEqual(count(), 0)

    def test_delete_tenant_removes_only_that_company(self):
        self._two_issues()
        other = self.tenant + "-other"
        self.tx.run("CREATE (:WorkItem {uid:$u, tenant_id:$t})", u=other + ":x", t=other)
        while ingest.delete_tenant(self.tx, self.tenant, limit=1):
            pass
        left = self.tx.run("MATCH (n) WHERE n.tenant_id IN [$a, $b] RETURN n.tenant_id AS t", a=self.tenant, b=other)
        self.assertEqual([r["t"] for r in left], [other])

    def test_delete_removes_everything_and_recreate_stores_again(self):
        jira_id, child_id = uuid.uuid4().hex, uuid.uuid4().hex
        key, child = "DEL-" + uuid.uuid4().hex[:8].upper(), "DEL-" + uuid.uuid4().hex[:8].upper()
        parent = {"id": jira_id, "key": key, "self": f"https://{self.site}/rest/api/3/issue/{jira_id}",
                  "fields": {"project": {"key": "DEL"}, "summary": "parent", "issuetype": {"name": "Story"},
                             "updated": "2026-10-27T10:00:00.000+0000",
                             "comment": {"comments": [{"id": uuid.uuid4().hex, "body": "c",
                                                       "created": "2026-10-27T10:00:00.000+0000",
                                                       "updated": "2026-10-27T10:00:00.000+0000"}]},
                             "attachment": [{"id": uuid.uuid4().hex, "filename": "a.png", "mimeType": "image/png",
                                             "size": 1, "created": "2026-10-27T10:00:00.000+0000"}]}}
        sub = {"id": child_id, "key": child, "self": f"https://{self.site}/rest/api/3/issue/{child_id}",
               "fields": {"project": {"key": "DEL"}, "summary": "child", "issuetype": {"name": "Subtask"},
                          "updated": "2026-10-27T10:00:00.000+0000",
                          "parent": {"id": jira_id, "key": key}}}
        for item in (parent, sub):
            self.assertEqual(ingest.upsert_issue(self.tx, item, self.tenant, site_id=self.site,
                                                 payload_mode="full"), "upserted")
        ingest.delete_issue(self.tx, key, self.tenant, jira_id=jira_id, site_id=self.site)
        left = self.tx.run("MATCH (n) WHERE n.tenant_id = $t AND n.jira_site_id = $s "
                           "AND NOT n:Project RETURN count(n) AS n", t=self.tenant, s=self.site).single()["n"]
        self.assertEqual(left, 0)
        self.assertEqual(self.tx.run("MATCH (d:DeletionTombstone {tenant_id: $t}) RETURN count(d) AS n",
                                     t=self.tenant).single()["n"], 0)
        self.assertEqual(ingest.upsert_issue(self.tx, parent, self.tenant, site_id=self.site,
                                             payload_mode="full"), "upserted")
        count = self.tx.run("MATCH (w:WorkItem {uid:$uid}) RETURN count(w) AS n",
                            uid=ingest.workitem_uid(self.tenant, self.site, jira_id)).single()["n"]
        self.assertEqual(count, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
