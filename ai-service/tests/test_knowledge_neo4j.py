"""Knowledge sources against a real Neo4j: cursor, publish, replace, remove, scoped search, Jira disconnect.

  $env:NEO4J_INTEGRATION="1"; python -m unittest -v test_knowledge_neo4j

Embeddings are fixed vectors (no Ollama needed). Each test uses a random company and removes what it wrote.
"""
import os
import unittest
import uuid

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.graph import ingest
from syntrace_ai.workers import knowledge_worker as kw
from syntrace_ai.graph.query_engine import AccessContext, get_driver, run_query
from test_knowledge_worker import FakeBackend

READY = os.getenv("NEO4J_INTEGRATION") == "1" and bool(os.getenv("NEO4J_URI"))


def embed(texts):
    """Database questions point one way, everything else the other."""
    return [[1.0, 0.0] if "postgres" in t.lower() or "database" in t.lower() else [0.0, 1.0] for t in texts]


def view(source_id, version, *evidence, project="p1"):
    return {"source": {"id": source_id, "kind": "MeetingNotes", "title": f"Meeting {source_id}",
                       "publishedVersion": version}, "meetingAt": "2026-11-20T10:00:00Z",
            "evidence": [dict(id=f"{source_id}-e{i}", decision="Approved", **e) for i, e in enumerate(evidence)]}


DB = {"kind": "Decision", "text": "Use PostgreSQL", "quote": "اتفقنا نستخدم PostgreSQL"}
UI = {"kind": "Requirement", "text": "Dark mode in settings", "quote": "وعايزين dark mode"}


@unittest.skipUnless(READY, "set NEO4J_INTEGRATION=1 and NEO4J_URI")
class KnowledgeNeo4jTests(unittest.TestCase):
    def setUp(self):
        self.tenant = f"test-knowledge-{uuid.uuid4().hex[:8]}"
        self.addCleanup(lambda: run_query("MATCH (n) WHERE n.tenant_id = $t DETACH DELETE n", t=self.tenant))

    def count(self, label):
        return run_query(f"MATCH (n:{label} {{tenant_id: $t}}) RETURN count(n) AS n", t=self.tenant)[0]["n"]

    def search(self, question, *projects):
        return kw.search_knowledge(question, AccessContext(self.tenant, (), None, projects), embed=embed)

    def test_publish_replace_remove_and_cursor(self):
        backend = FakeBackend(changes=[
            {"cursor": 1, "sourceId": "s1", "projectId": "p1", "version": 1},
            {"cursor": 2, "sourceId": "s1", "projectId": "p1", "version": 2},
            {"cursor": 3, "sourceId": "s2", "projectId": "p2", "version": 1}],
            views={("s1", 1): view("s1", 1, DB, UI), ("s1", 2): view("s1", 2, DB),
                   ("s2", 1): view("s2", 1, UI, project="p2")})
        self.assertEqual(kw.apply_changes(backend, self.tenant, embed=embed), 3)
        self.assertEqual(self.count("KnowledgeSource"), 2)
        self.assertEqual(self.count("KnowledgeEvidence"), 2)          # version 2 replaced version 1
        self.assertEqual(kw._cursor(self.tenant), 3)
        self.assertEqual(kw.apply_changes(backend, self.tenant, embed=embed), 0)

        backend._changes.append({"cursor": 4, "sourceId": "s1", "projectId": "p1", "version": 2, "removed": True})
        self.assertEqual(kw.apply_changes(backend, self.tenant, embed=embed), 1)
        self.assertEqual(self.count("KnowledgeSource"), 1)
        self.assertEqual(self.search("which database", "p1"), [])

    def test_search_is_scoped_to_allowed_projects(self):
        kw.index_published(self.tenant, "p1", view("s1", 1, DB), embed=embed)
        kw.index_published(self.tenant, "p2", view("s2", 1, dict(DB, text="Use PostgreSQL 16")), embed=embed)
        self.assertEqual([h["source_id"] for h in self.search("which database", "p1")], ["s1"])
        self.assertEqual(len(self.search("which database", "p1", "p2")), 2)
        self.assertEqual(self.search("which database"), [])                        # deny by default
        other = kw.search_knowledge("which database", AccessContext("someone-else", (), None, ("p1",)), embed=embed)
        self.assertEqual(other, [])

    def test_jira_disconnect_keeps_knowledge(self):
        kw.index_published(self.tenant, "p1", view("s1", 1, DB), embed=embed)
        kw._save_cursor(self.tenant, 7)
        with get_driver().session() as session:
            while session.execute_write(lambda tx: ingest.delete_tenant(tx, self.tenant, keep_labels=ingest.MEETING_LABELS)):
                pass
        self.assertEqual(self.count("KnowledgeEvidence"), 1)
        self.assertEqual(kw._cursor(self.tenant), 7)


if __name__ == "__main__":
    unittest.main()
