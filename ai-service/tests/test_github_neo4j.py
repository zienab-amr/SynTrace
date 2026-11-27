"""The GitHub side against a real Neo4j: every event type, ordering, revocation and the assistant's queries.

  $env:NEO4J_INTEGRATION="1"; python -m unittest -v test_github_neo4j

Embeddings are fixed vectors (no Ollama needed). Each test uses a random company and removes what it wrote.
"""
import os
import unittest
import uuid

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.github import github_graph as gg
from syntrace_ai.graph import ingest
from github_fixtures import code_file, commit, file_removed, pull_request, revoked, sync_completed, SHA2
from syntrace_ai.graph.query_engine import AccessContext, get_driver, run_query

READY = os.getenv("NEO4J_INTEGRATION") == "1" and bool(os.getenv("NEO4J_URI"))


def embed(texts):
    return [[1.0, 0.0] if "google" in t.lower() else [0.0, 1.0] for t in texts]


@unittest.skipUnless(READY, "set NEO4J_INTEGRATION=1 and NEO4J_URI")
class GitHubNeo4jTests(unittest.TestCase):
    def setUp(self):
        self.tenant = f"test-github-{uuid.uuid4().hex[:8]}"
        self.ctx = AccessContext(self.tenant, ("SYNT",), None, ("p1",))
        self.addCleanup(lambda: run_query("MATCH (n) WHERE n.tenant_id = $t DETACH DELETE n", t=self.tenant))

    def apply(self, e):
        e["companyId"] = self.tenant
        with get_driver().session() as session:
            return session.execute_write(lambda tx: gg.apply_event(tx, e))

    def count(self, label, where=""):
        return run_query(f"MATCH (n:{label}) WHERE n.tenant_id = $t {where} RETURN count(n) AS n", t=self.tenant)[0]["n"]

    def test_lifecycle(self):
        self.assertEqual(self.apply(commit(1)), "upserted")
        self.assertEqual(self.apply(pull_request(2)), "upserted")
        self.assertEqual(self.apply(code_file(3)), "upserted")
        self.assertEqual(self.apply(sync_completed(4)), "completed")
        self.assertEqual(self.apply(commit(1)), "stale")                  # redelivered
        self.assertEqual(self.count("Commit"), 1)
        self.assertEqual(self.count("CodeChunk"), 2)                     # 81 lines: 1-60 and 51-81
        repo = run_query("MATCH (r:GitHubRepository) WHERE r.tenant_id = $t RETURN r", t=self.tenant)[0]["r"]
        self.assertEqual((repo["full_name"], repo["skipped_files"]), ("syntrace-team/SynTrace", 2))

        result = gg.activity(self.ctx, run_query, key="SYNT-12")
        self.assertEqual((result["pr_total"], result["commit_total"]), (1, 1))
        self.assertTrue(result["pull_requests"][0]["merged"])
        self.assertEqual(result["repos"], ["syntrace-team/SynTrace"])
        self.assertEqual(gg.activity(self.ctx, run_query, state="open")["pr_total"], 0)
        self.assertEqual(gg.activity(self.ctx, run_query, author="ZIENAB")["commit_total"], 1)
        self.assertEqual(gg.activity(self.ctx, run_query, text="google", kind="commit")["commit_total"], 1)
        self.assertEqual(gg.activity(AccessContext(self.tenant, ("SYNT",), None, ("p2",)), run_query)["pr_total"], 0)

        self.assertEqual(gg.embed_pending(self.tenant, run_query, embed), 4)   # commit, PR, 2 chunks
        self.assertEqual(self.count("CodeChunk", "AND n.needs_embedding"), 0)
        hits = gg.search_code("google login", self.ctx, run_query, embed)
        self.assertIn("code", {h["kind"] for h in hits})
        self.assertTrue(any(h["kind"] == "code" and h["url"].endswith("#L51-L81") for h in hits))

    def test_file_versions_tombstone_and_late_events(self):
        self.apply(code_file(1))
        gg.embed_pending(self.tenant, run_query, embed)
        self.apply(code_file(2))                                     # same blob, new head: no re-chunk
        self.assertEqual(self.count("CodeChunk", "AND n.needs_embedding"), 0)
        self.assertEqual(self.count("CodeChunk", "AND n.source_version = 2"), 2)
        self.apply(code_file(3, content="def google():\n    pass", blob="e" * 40))
        self.assertEqual(self.count("CodeChunk"), 1)
        self.assertEqual(self.count("CodeChunk", "AND n.needs_embedding"), 1)
        self.assertEqual(self.apply(file_removed(4)), "removed")
        self.assertEqual(self.count("CodeChunk"), 0)
        self.assertEqual(self.apply(code_file(3)), "stale")         # a retry of an older upsert
        self.assertEqual(self.count("CodeFile", "AND n.removed"), 1)
        self.assertEqual(self.apply(code_file(5)), "upserted")      # back on the branch
        self.assertEqual(self.count("CodeFile", "AND n.removed"), 0)

    def test_embedding_skips_a_node_changed_meanwhile(self):
        self.apply(commit(1))
        rows = run_query("MATCH (n:Commit) WHERE n.tenant_id = $t RETURN n.uid AS uid", t=self.tenant)
        self.apply(commit(2, message="SYNT-12 rename endpoint"))
        run_query("UNWIND $rows AS r MATCH (n:Commit {uid: r.uid}) WHERE n.source_version = r.v "
                  "SET n.needs_embedding = false", rows=[{"uid": rows[0]["uid"], "v": 1}])
        self.assertEqual(self.count("Commit", "AND n.needs_embedding"), 1)

    def test_revocation_forgets_everything(self):
        self.apply(commit(1))
        self.apply(code_file(2))
        self.apply(pull_request(3, number=8, merged=False))
        other = commit(1, binding="b2", sha=SHA2)
        self.apply(other)
        self.assertEqual(self.apply(revoked(4)), "revoked")
        for label in ("PullRequest", "CodeFile", "CodeChunk"):
            self.assertEqual(self.count(label), 0, label)
        self.assertEqual(self.count("Commit"), 1)                    # the other repository stays
        self.assertEqual(self.apply(commit(3)), "stale")            # a late retry can't bring it back
        self.assertEqual(self.apply(commit(5)), "upserted")         # bound again later

    def test_identity_gives_the_jira_name(self):
        self.apply(pull_request(1))
        run_query("CREATE (:Person {uid: $u, tenant_id: $t, accountId: 'acc-1', displayName: 'Zienab Amr'})",
                  u=f"{self.tenant}:person:acc-1", t=self.tenant)
        with get_driver().session() as session:
            session.execute_write(lambda tx: gg.link_identities(tx, self.tenant, [
                {"employeeId": "e1", "jiraAccountId": "acc-1", "gitHubUserId": 9, "gitHubLogin": "zienab-amr"}]))
        result = gg.activity(self.ctx, run_query, author="zienab amr")
        self.assertEqual(result["pull_requests"][0]["author_name"], "Zienab Amr")
        self.assertIn("(Jira: Zienab Amr)", gg.activity_context(result))
        with get_driver().session() as session:   # unlinked: the next list no longer has them
            session.execute_write(lambda tx: gg.link_identities(tx, self.tenant, []))
        self.assertIsNone(gg.activity(self.ctx, run_query)["pull_requests"][0]["author_name"])

    def test_jira_vs_github(self):
        for key, category in (("SYNT-12", "done"), ("SYNT-13", "indeterminate"), ("SYNT-14", "done")):
            run_query("CREATE (:WorkItem {uid: $u, tenant_id: $t, key: $k, project_key: 'SYNT', summary: 's', "
                      "status: 'x', statusCategory: $c})", u=f"{self.tenant}:wi:{key}", t=self.tenant, k=key, c=category)

        def about(e, key, state=None):
            if state:
                e["payload"]["state"] = state
            e["payload"]["jiraKeys"] = [key]
            e["payload"]["title"] = e["payload"].get("title") and f"{key} work"
            e["payload"]["body"] = ""
            if "message" in e["payload"]:
                e["payload"]["message"] = f"{key} work"
            return e
        self.apply(about(pull_request(1, number=7, merged=False), "SYNT-12", "closed"))   # done, never merged
        self.apply(about(pull_request(2, number=8, merged=True), "SYNT-13"))    # merged, ticket still open
        self.apply(about(pull_request(3, number=9, merged=False), "SYNT-14", "closed"))   # applied by hand:
        self.apply(about(commit(4), "SYNT-14"))                                  # its commit is on the branch
        result = gg.jira_vs_github(self.ctx, run_query)
        self.assertEqual([i["key"] for i in result["items"]["done_unmerged"]], ["SYNT-12"])
        self.assertEqual([i["key"] for i in result["items"]["merged_open"]], ["SYNT-13"])
        self.assertEqual(result["counts"]["open_pr_done"], 0)
        self.apply(about(pull_request(5, number=10, merged=False), "SYNT-14", "open"))   # done, PR still open
        self.assertEqual([i["key"] for i in gg.jira_vs_github(self.ctx, run_query)["items"]["open_pr_done"]], ["SYNT-14"])

    def test_moved_ticket_finds_commits_with_its_old_key(self):
        run_query("CREATE (:WorkItem {uid: $u, tenant_id: $t, key: 'SYNT-40', project_key: 'SYNT', "
                  "key_aliases: ['SYNT-12']})", u=f"{self.tenant}:wi:SYNT-40", t=self.tenant)
        self.apply(commit(1))                                  # its message says SYNT-12
        result = gg.activity(self.ctx, run_query, key="SYNT-40")
        self.assertEqual(result["commit_total"], 1)

    def test_repository_moved_to_another_project(self):
        self.apply(commit(1))
        self.apply(code_file(2))
        moved = commit(3, sha=SHA2)
        moved["projectId"] = "p2"
        self.apply(moved)
        self.assertEqual(self.count("Commit", "AND n.syntrace_project_id = 'p2'"), 2)
        self.assertEqual(self.count("CodeChunk", "AND n.syntrace_project_id = 'p1'"), 0)
        self.assertEqual(gg.activity(self.ctx, run_query)["commit_total"], 0)        # p1 sees nothing now
        p2 = AccessContext(self.tenant, ("SYNT",), None, ("p2",))
        self.assertEqual(gg.activity(p2, run_query)["commit_total"], 2)
        late = pull_request(2)                                  # from before the move
        self.apply(late)
        self.assertEqual(gg.activity(p2, run_query)["pr_total"], 1)

    def test_unchanged_text_keeps_its_embedding(self):
        self.apply(commit(1))
        gg.embed_pending(self.tenant, run_query, embed)
        self.apply(commit(2))                                   # same text again
        self.assertEqual(self.count("Commit", "AND n.needs_embedding"), 0)
        self.apply(commit(3, message="SYNT-12 rename the endpoint"))
        self.assertEqual(self.count("Commit", "AND n.needs_embedding"), 1)

    def test_other_projects_keys_are_hidden(self):
        self.apply(commit(1, message="SYNT-12 and HR-3 together"))
        e = commit(2, message="SYNT-12 and HR-3 together")
        e["payload"]["jiraKeys"] = ["SYNT-12", "HR-3"]
        self.apply(e)
        item = gg.activity(self.ctx, run_query, key="SYNT-12")["commits"][0]
        self.assertEqual(item["keys"], ["SYNT-12"])

    def test_code_progress_of_an_epic(self):
        def ticket(key, kind, category, parent=None):
            run_query("CREATE (:WorkItem {uid: $u, tenant_id: $t, key: $k, project_key: 'SYNT', summary: $k, "
                      "issuetype: $kind, status: 'x', statusCategory: $c})",
                      u=f"{self.tenant}:wi:{key}", t=self.tenant, k=key, kind=kind, c=category)
            if parent:
                run_query("MATCH (c:WorkItem {uid: $c}), (p:WorkItem {uid: $p}) CREATE (c)-[:CHILD_OF]->(p)",
                          c=f"{self.tenant}:wi:{key}", p=f"{self.tenant}:wi:{parent}")
        ticket("SYNT-1", "Epic", "indeterminate")
        ticket("SYNT-10", "Story", "indeterminate", "SYNT-1")
        ticket("SYNT-12", "Sub-task", "done", "SYNT-10")      # two levels down: the fixture PR and commit
        ticket("SYNT-13", "Sub-task", "new", "SYNT-10")
        self.apply(pull_request(1))
        self.apply(commit(2))
        result = gg.code_progress(self.ctx, run_query, "SYNT-1")
        self.assertEqual(result["totals"]["tickets"], 4)
        self.assertEqual(result["totals"]["merged"], 1)
        self.assertEqual(result["totals"]["no_code"], 3)
        self.assertIn("SYNT-12 | Sub-task", gg.code_progress_context(result))

    def test_stuck_pull_requests(self):
        old = pull_request(1, number=7, merged=False)
        old["payload"]["updatedAt"] = "2020-01-01T00:00:00Z"
        self.apply(old)
        fresh = pull_request(2, number=8, merged=False)
        fresh["payload"]["updatedAt"] = "2999-01-01T00:00:00Z"
        self.apply(fresh)
        self.apply(pull_request(3, number=9, merged=True))     # merged: never stuck
        result = gg.activity(self.ctx, run_query, idle_days=14)
        self.assertEqual([p["number"] for p in result["pull_requests"]], [7])

    def test_commit_to_its_story_and_subtasks(self):
        for key, kind, parent in (("SYNT-1", "Epic", None), ("SYNT-10", "Story", "SYNT-1"),
                                  ("SYNT-12", "Sub-task", "SYNT-10"), ("SYNT-13", "Sub-task", "SYNT-10")):
            run_query("CREATE (:WorkItem {uid: $u, tenant_id: $t, key: $k, project_key: 'SYNT', summary: $k, "
                      "issuetype: $kind, status: 'x'})", u=f"{self.tenant}:wi:{key}", t=self.tenant, k=key, kind=kind)
            if parent:
                run_query("MATCH (c:WorkItem {uid: $c}), (p:WorkItem {uid: $p}) CREATE (c)-[:CHILD_OF]->(p)",
                          c=f"{self.tenant}:wi:{key}", p=f"{self.tenant}:wi:{parent}")
        family = gg.ticket_family(self.ctx, run_query, ["SYNT-12", "SYNT-10"])
        by_key = {t["key"]: t for t in family}
        self.assertEqual([a["key"] for a in by_key["SYNT-12"]["above"]], ["SYNT-10", "SYNT-1"])
        self.assertEqual([c["key"] for c in by_key["SYNT-10"]["under"]], ["SYNT-12", "SYNT-13"])

    def test_merged_in_a_month(self):
        for v, number, merged_at in ((1, 7, "2015-01-10T10:00:00Z"), (2, 8, "2015-02-01T00:00:01Z"), (3, 9, None)):
            e = pull_request(v, number=number, merged=bool(merged_at))
            e["payload"]["mergedAt"] = merged_at
            self.apply(e)
        result = gg.activity(self.ctx, run_query, state="merged", from_date="2015-01", to_date="2015-01")
        self.assertEqual([p["number"] for p in result["pull_requests"]], [7])

    def test_jira_project_named_as_the_repository(self):
        self.apply(pull_request(1))                          # mentions SYNT-12, in binding b1
        self.assertEqual(gg.activity(self.ctx, run_query, repository="SYNT")["pr_total"], 1)
        self.assertEqual(gg.activity(self.ctx, run_query, repository="syntrace-team/SynTrace")["pr_total"], 1)
        self.assertEqual(gg.activity(self.ctx, run_query, repository="other-repo")["pr_total"], 0)

    def test_indexing_status(self):
        self.apply(commit(1))
        self.apply(code_file(2))
        rows = gg.indexing_status(self.ctx, run_query)
        self.assertEqual(rows[0]["status"], "not_synced")
        self.assertEqual((rows[0]["commits"], rows[0]["files"]), (1, 1))
        self.apply(sync_completed(3))                          # 2 files skipped (max_file_bytes)
        gg.embed_pending(self.tenant, run_query, embed)
        rows = gg.indexing_status(self.ctx, run_query)
        self.assertEqual(rows[0]["status"], "partial")
        self.assertIn("files larger than 64 KB", gg.indexing_status_context(rows))

    def test_jira_disconnect_keeps_github(self):
        self.apply(commit(1))
        with get_driver().session() as session:
            while session.execute_write(lambda tx: ingest.delete_tenant(tx, self.tenant, keep_labels=ingest.MEETING_LABELS)):
                pass
        self.assertEqual(self.count("Commit"), 1)
        self.assertEqual(self.count("GitHubRepository"), 1)


LAB_DIR = os.getenv("GITHUB_LAB_DIR", r"B:\graphrag_lab\github_lab")


@unittest.skipUnless(READY and os.path.isdir(LAB_DIR), "needs the lab Neo4j and its GitHub dataset")
class LabRetrievalReport(unittest.TestCase):
    """Search quality on the lab's real repositories, no LLM: a ticket's summary should find its GitHub work."""

    def test_ticket_summary_finds_its_github_work(self):
        import github_retrieval_eval
        from syntrace_ai.graph.embeddings import embed_texts
        report = github_retrieval_eval.evaluate(LAB_DIR, "lab", run_query, embed_texts, per_project=25)
        print("\nGitHub retrieval (ticket summary -> its PR, commit or changed file in the top 5):")
        for project, row in report.items():
            print(f"  {project:10} {row}")
        measured = [row["recall@5"] for row in report.values() if row["tickets"]]
        self.assertTrue(measured)
        self.assertGreater(sum(measured) / len(measured), 0.2)   # far below this means search is broken


if __name__ == "__main__":
    unittest.main()
