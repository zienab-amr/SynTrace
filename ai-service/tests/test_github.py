"""Offline tests for the GitHub side: events, chunks, consumer decisions and the assistant's tools.
  python -m unittest test_github -v
"""
import json
import os
import unittest
from unittest import mock

from syntrace_ai.workers import github_consumer
from syntrace_ai.github import github_graph as gg
from github_fixtures import body, code_file, commit, pull_request, revoked, SHA1
from syntrace_ai.graph.query_engine import AccessContext

CTX = AccessContext("c1", ("SYNT",), None, ("p1",))


class ParseTests(unittest.TestCase):
    def test_backend_shape_is_accepted(self):
        e = gg.parse_event(commit(3))
        self.assertEqual((e["companyId"], e["projectId"], e["bindingId"], e["sourceVersion"]), ("c1", "p1", "b1", 3))

    def test_missing_fields_are_bad_events(self):
        for field in ("eventType", "companyId", "projectId", "bindingId", "entityId"):
            e = commit(3)
            e[field] = None
            with self.assertRaises(gg.BadEvent):
                gg.parse_event(e)
        with self.assertRaises(gg.BadEvent):
            gg.parse_event(dict(commit(3), sourceVersion="x"))

    def test_keys_are_checked_and_deduplicated(self):
        self.assertEqual(gg._keys(["synt-12", "SYNT-12", "UTF8", "x-1", "AB-3"]), ["SYNT-12", "AB-3"])

    def test_repo_name_from_url(self):
        self.assertEqual(gg._full_name("https://github.com/syntrace-team/SynTrace/pull/7"), "syntrace-team/SynTrace")


class ChunkTests(unittest.TestCase):
    def test_windows_overlap_and_link_their_lines(self):
        code = "\n".join(f"line {i}" for i in range(1, 131))
        parts = gg.chunks(code, "a.py", "https://github.com/o/r/blob/h/a.py#L1-L130")
        self.assertEqual([(p["start_line"], p["end_line"]) for p in parts], [(1, 60), (51, 110), (101, 130)])
        self.assertTrue(parts[1]["url"].endswith("a.py#L51-L110"))
        self.assertTrue(parts[1]["text"].startswith("line 51"))

    def test_long_lines_get_smaller_windows(self):
        code = "\n".join("x" * 200 for _ in range(60))
        parts = gg.chunks(code, "a.min.js", None)
        self.assertTrue(all(len(p["text"]) <= gg.CHUNK_CHARS for p in parts))
        self.assertEqual(parts[-1]["end_line"], 60)

    def test_empty_file_has_no_chunks(self):
        self.assertEqual(gg.chunks("", "a.py", None), [])


class FakeTx:
    """Answers apply_event's reads from a dict of uid -> source_version."""
    def __init__(self, versions=None, revoked=None):
        self.versions, self.revoked, self.queries = versions or {}, revoked, []

    def run(self, query, **params):
        self.queries.append((query, params))
        result = mock.Mock()
        if "GitHubRevoked" in query and query.startswith("MATCH"):
            result.single.return_value = {"v": self.revoked} if self.revoked is not None else None
        elif query.startswith("MATCH (n:CodeFile {uid: $uid}) RETURN"):
            v = self.versions.get(params["uid"])
            result.single.return_value = {"v": v, "blob": "old"} if v is not None else None
        elif "MERGE (n:" in query and "RETURN n.uid" in query:
            v = self.versions.get(params["uid"])
            new = v is None or v < params["props"]["source_version"]
            result.single.return_value = {"uid": params["uid"]} if new else None
        else:
            result.single.return_value = None
        return result


class ApplyTests(unittest.TestCase):
    def test_commit_props(self):
        tx = FakeTx()
        self.assertEqual(gg.apply_event(tx, commit(3)), "upserted")
        props = next(p for q, p in tx.queries if "MERGE (n:Commit" in q)["props"]
        self.assertEqual(props["jira_keys"], ["SYNT-12"])
        self.assertEqual(props["title"], "SYNT-12 add Google login endpoint")
        self.assertEqual(props["file_paths"], ["backend/AuthController.cs"])
        self.assertEqual((props["additions"], props["deletions"]), (40, 3))
        self.assertEqual(props["syntrace_project_id"], "p1")
        repo = next(p for q, p in tx.queries if "SET r += $props" in q)
        self.assertEqual(repo["props"]["full_name"], "syntrace-team/SynTrace")

    def test_older_event_is_stale(self):
        tx = FakeTx({gg.uid("c1", "b1", "commit", SHA1): 5})
        self.assertEqual(gg.apply_event(tx, commit(3)), "stale")

    def test_pull_request_merged_flag(self):
        tx = FakeTx()
        gg.apply_event(tx, pull_request(4, merged=True))
        props = next(p for q, p in tx.queries if "MERGE (n:PullRequest" in q)["props"]
        self.assertTrue(props["merged"])
        self.assertEqual(props["commit_shas"], [SHA1])
        gg.apply_event(tx, pull_request(5, merged=False, number=8))
        props = [p for q, p in tx.queries if "MERGE (n:PullRequest" in q][-1]["props"]
        self.assertFalse(props["merged"])
        self.assertEqual(props["state"], "open")

    def test_file_is_chunked(self):
        tx = FakeTx()
        self.assertEqual(gg.apply_event(tx, code_file(6)), "upserted")
        rows = next(p for q, p in tx.queries if "CREATE (c:CodeChunk)" in q)["rows"]
        self.assertEqual(rows[0]["start_line"], 1)
        self.assertTrue(all(r["needs_embedding"] for r in rows))
        self.assertTrue(any("GoogleLogin" in r["text"] for r in rows))

    def test_events_after_revocation_and_bad_commit(self):
        self.assertEqual(gg.apply_event(FakeTx(revoked=9), commit(3)), "stale")
        with self.assertRaises(gg.BadEvent):
            gg.apply_event(FakeTx(), commit(3, sha="nope"))

    def test_unknown_event_type_is_ignored(self):
        e = commit(3)
        e["eventType"] = "github.release.upserted"
        self.assertEqual(gg.apply_event(FakeTx(), e), "ignored")


class ProcessorTests(unittest.TestCase):
    def processor(self, outcome=None, error=None):
        session = mock.MagicMock()
        session.__enter__.return_value = session
        session.execute_write.side_effect = error if error else (lambda work: outcome)
        bumped, embedded = [], []
        p = github_consumer.GitHubProcessor(session_factory=lambda: session, embed=embedded.append,
                                            bump=bumped.append)
        return p, bumped, embedded

    def test_applied_event_bumps_cache_and_wakes_embeddings(self):
        p, bumped, embedded = self.processor("upserted")
        self.assertEqual(p.process(body(commit(3))).action, "ack")
        self.assertEqual((bumped, embedded), (["c1"], ["c1"]))

    def test_stale_event_changes_nothing(self):
        p, bumped, embedded = self.processor("stale")
        self.assertEqual(p.process(body(commit(3))).action, "ack")
        self.assertEqual((bumped, embedded), ([], []))

    def test_revoked_bumps_without_embedding(self):
        p, bumped, embedded = self.processor("revoked")
        p.process(body(revoked(9)))
        self.assertEqual((bumped, embedded), (["c1"], []))

    def test_bad_json_and_bad_event_go_dead(self):
        p, _, _ = self.processor("upserted")
        self.assertEqual(p.process(b"{nope").action, "dead")
        self.assertEqual(p.process(json.dumps({"eventType": "x"}).encode()).action, "dead")

    def test_neo4j_down_retries(self):
        from neo4j.exceptions import ServiceUnavailable
        p, _, _ = self.processor(error=ServiceUnavailable("down"))
        with mock.patch("time.sleep"):
            self.assertEqual(p.process(body(commit(3))).action, "retry")

    def test_topology_matches_the_backend(self):
        channel = mock.Mock()
        github_consumer.declare_topology(channel, github_consumer.GitHubSettings())
        channel.queue_declare.assert_any_call("syntrace.ai.github", durable=True)
        channel.queue_bind.assert_any_call("syntrace.ai.github", "syntrace.github.events", "github.ai.v1")
        exchanges = [c.args[0] for c in channel.exchange_declare.call_args_list]
        self.assertNotIn("syntrace.ai.retry", exchanges)   # never shares the Jira retry exchange


class QueryScopeTests(unittest.TestCase):
    def test_no_syntrace_projects_means_no_github(self):
        run = mock.Mock()
        ctx = AccessContext("c1", ("SYNT",))
        self.assertEqual(gg.activity(ctx, run)["pull_requests"], [])
        self.assertEqual(gg.search_code("login", ctx, run, embed=lambda t: [[1.0]]), [])
        run.assert_not_called()

    def test_ticket_of_another_project_is_not_shown(self):
        run = mock.Mock(return_value=[])                    # HR-3 is not in the asker's projects
        self.assertEqual(gg.activity(CTX, run, key="HR-3")["commits"], [])
        self.assertEqual(run.call_count, 1)                 # only the ticket lookup, no GitHub query

    def test_activity_passes_scope(self):
        run = mock.Mock(side_effect=lambda q, **p: [] if "WorkItem" in q else [{"total": 0, "items": []}])
        gg.activity(CTX, run, key="synt-12", author="Zienab", state="merged")
        for call in run.call_args_list[1:]:
            self.assertEqual(call.kwargs["t"], "c1")
            self.assertEqual(call.kwargs["projects"], ["p1"])
            self.assertEqual(call.kwargs["key"], "SYNT-12")
            self.assertEqual(call.kwargs["author"], "zienab")

    def test_search_ranks_and_labels_kinds(self):
        def row(uid, emb, **kw):
            base = dict.fromkeys(gg._FIELDS)
            base.update(uid=uid, emb=emb, **kw)
            return base
        by_label = {
            "CodeChunk": [row("u1", [1.0, 0.0], path="a.cs", start_line=1, end_line=60, text="GoogleLogin", url="u1")],
            "PullRequest": [row("u2", [0.8, 0.6], number=7, title="Google login", url="u2", keys=["SYNT-12"],
                                author="zienab-amr", date="2026-11-20")],
            "Commit": [row("u3", [0.0, 1.0], title="docs", sha="abc1234", url="u3", keys=[], author="x")],
        }
        queries = []

        def run(query, **params):
            queries.append(query)
            if query.startswith("UNWIND $uids"):
                return [{"uid": u} for u in params["uids"]]
            label = query.split("(n:")[1].split(")")[0]
            return by_label[label]
        gg._VECTORS.clear()
        hits = gg.search_code("google login", CTX, run, embed=lambda t: [[1.0, 0.0]])
        self.assertEqual([h["kind"] for h in hits], ["code", "pull_request"])
        self.assertFalse(any(q.startswith("MATCH (n) ") for q in queries))   # every query names its label
        text = gg.code_context(hits)
        self.assertIn("a.cs lines 1-60", text)
        self.assertIn("PR #7", text)
        n = len(queries)
        gg.search_code("google login", CTX, run, embed=lambda t: [[1.0, 0.0]])
        self.assertEqual(sum(1 for q in queries[n:] if "embedding IS NOT NULL" in q), 0)   # vectors cached
        gg._VECTORS.clear()

    def test_deleted_node_is_not_shown_from_the_cache(self):
        rows = {"CodeChunk": [dict(dict.fromkeys(gg._FIELDS), uid="gone", emb=[1.0], path="a.py", start_line=1)],
                "PullRequest": [], "Commit": []}

        def run(query, **params):
            if query.startswith("UNWIND $uids"):
                return []
            return rows[query.split("(n:")[1].split(")")[0]]
        gg._VECTORS.clear()
        self.assertEqual(gg.search_code("anything", CTX, run, embed=lambda t: [[1.0]]), [])
        gg._VECTORS.clear()


class AgentTests(unittest.TestCase):
    RESULT = {"repos": ["syntrace-team/SynTrace"], "pr_total": 1, "commit_total": 0, "commits": [],
              "pull_requests": [{"number": 7, "title": "SYNT-12 Google login", "state": "closed", "merged": True,
                                 "draft": False, "merged_at": "2026-11-20T09:00:00Z", "created_at": "2026-11-18",
                                 "author": "zienab-amr", "head": "feature/x", "base": "main", "keys": ["SYNT-12"],
                                 "url": "https://github.com/syntrace-team/SynTrace/pull/7", "repo": "syntrace-team/SynTrace",
                                 "commits": 1, "files": 1, "additions": 40, "deletions": 3}]}

    def walk(self, ctx=CTX):
        from syntrace_ai.assistant import graph_agent
        return graph_agent.Walk(ctx)

    def test_activity_tool_and_answer_check(self):
        from syntrace_ai.assistant import graph_agent
        walk = self.walk()
        with mock.patch("syntrace_ai.github.github_graph.activity", return_value=self.RESULT), mock.patch("syntrace_ai.graph.query_engine.run_query"):
            out = walk.github_activity({"key": "SYNT-12", "state": "merged"})
        self.assertIn("PR #7 | merged 2026-11-20", out)
        self.assertTrue(walk.github)
        walk.urls.setdefault("SYNT-12", None)   # run() does this for keys inside a tool result
        result = graph_agent._checked("SYNT-12 اتعملها merge في PR #7 يوم 2026-11-20.", walk)
        self.assertEqual(result["source"], "github")
        self.assertIsNone(graph_agent._checked("SYNT-99 merged", walk))   # a key no tool returned

    def test_tools_refuse_without_syntrace_projects(self):
        walk = self.walk(AccessContext("c1", ("SYNT",)))
        self.assertEqual(walk.github_activity({}), "No GitHub repository is available to this user.")
        self.assertEqual(walk.search_code({"query": "login"}), "No GitHub repository is available to this user.")

    def test_bad_key_is_reported(self):
        self.assertEqual(self.walk().github_activity({"key": "login"}), "login is not a ticket key.")

    def test_tools_are_declared_and_dispatched(self):
        from syntrace_ai.assistant import graph_agent
        names = {t["function"]["name"] for t in graph_agent.TOOLS}
        self.assertTrue({"github_activity", "search_code"} <= names)
        call = mock.Mock()
        call.function.name, call.function.arguments = "search_code", '{"query": "login"}'
        walk = self.walk()
        with mock.patch("syntrace_ai.github.github_graph.search_code", return_value=[]), mock.patch("syntrace_ai.graph.embeddings.embed_texts"):
            self.assertEqual(walk.run(call), "No code, pull request or commit matches.")
        self.assertEqual(walk.read, 0)   # a search, not a read


class EmbeddingTests(unittest.TestCase):
    def test_embed_pending_writes_by_label_and_version(self):
        calls = []
        pending = [{"uid": "u1", "labels": ["CodeChunk"], "v": 6, "p": {"path": "a.cs", "start_line": 1, "end_line": 9, "text": "x"}},
                   {"uid": "u2", "labels": ["PullRequest"], "v": 4, "p": {"number": 7, "title": "t", "body": "b"}}]

        def run(query, **params):
            calls.append((query, params))
            return pending if query.startswith("MATCH (n) WHERE n.tenant_id") and len(calls) == 1 else []
        stored = gg.embed_pending("c1", run, lambda texts: [[0.1, 0.2]] * len(texts))
        self.assertEqual(stored, 2)
        writes = [q for q, _ in calls if q.startswith("UNWIND")]
        self.assertEqual(len(writes), 2)
        self.assertTrue(any("MATCH (n:CodeChunk {uid: r.uid})" in q for q in writes))
        self.assertTrue(all("n.source_version = r.v" in q for q in writes))


if __name__ == "__main__":
    unittest.main()


class FirstStepAndGuardTests(unittest.TestCase):
    def test_question_with_key_gets_github_activity_first(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(CTX)
        with mock.patch("syntrace_ai.github.github_graph.activity", return_value=AgentTests.RESULT), mock.patch("syntrace_ai.graph.query_engine.run_query"):
            msgs = graph_agent._github_first_step("مين عمل PR للـ SYNT-12؟", walk)
        self.assertEqual(msgs[0]["tool_calls"][0]["function"]["name"], "github_activity")
        self.assertIn('"SYNT-12"', msgs[0]["tool_calls"][0]["function"]["arguments"])
        self.assertIn("PR #7", msgs[1]["content"])

    def test_code_question_without_key_gets_search_code(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(CTX)
        with mock.patch("syntrace_ai.github.github_graph.search_code", return_value=[]), mock.patch("syntrace_ai.graph.embeddings.embed_texts"):
            msgs = graph_agent._github_first_step("In which file is StatementBuilder defined in our code?", walk)
        self.assertEqual(msgs[0]["tool_calls"][0]["function"]["name"], "search_code")

    def test_jira_question_gets_no_first_step(self):
        from syntrace_ai.assistant import graph_agent
        self.assertEqual(graph_agent._github_first_step("Who is assigned to SYNT-12?", graph_agent.Walk(CTX)), [])

    def test_invented_pull_request_is_replaced(self):
        from syntrace_ai.assistant import graph_agent
        message = mock.Mock(tool_calls=None, content="DATACASS-56 has https://github.com/o/r/pull/114 (PR #114).")
        with mock.patch.object(graph_agent, "_ask", return_value=message), \
                mock.patch.object(graph_agent, "_github_first_step", return_value=[]):
            result = graph_agent.answer("Which pull request was opened for DATACASS-56?", AccessContext("c1", ("DATACASS",)))
        self.assertNotIn("114", result["answer"])
        self.assertEqual(result["source"], "github")

    def test_name_hits_find_files_by_identifier(self):
        calls = []

        def run(query, **params):
            calls.append(params)
            if "embedding IS NOT NULL" in query:
                return []
            return [{"path": "src/StatementBuilder.java", "start_line": 1, "end_line": 60, "text": "class StatementBuilder",
                     "url": "u"}]
        hits = gg.search_code("Where is StatementBuilder defined?", CTX, run, embed=lambda t: [[1.0]])
        self.assertEqual(calls[0]["names"], ["statementbuilder"])
        self.assertEqual(hits[0]["path"], "src/StatementBuilder.java")


class IdentityTests(unittest.TestCase):
    def test_context_shows_the_jira_name(self):
        result = dict(AgentTests.RESULT)
        result["pull_requests"] = [dict(AgentTests.RESULT["pull_requests"][0], author_name="Zienab Amr")]
        self.assertIn("by zienab-amr (Jira: Zienab Amr)", gg.activity_context(result))
        result["pull_requests"] = [dict(AgentTests.RESULT["pull_requests"][0], author_name=None)]
        self.assertIn("by zienab-amr |", gg.activity_context(result))

    def test_link_identities_replaces_and_skips_bad_rows(self):
        tx = mock.Mock()
        n = gg.link_identities(tx, "c1", [
            {"employeeId": "e1", "jiraAccountId": "acc-1", "gitHubUserId": 9, "gitHubLogin": "zienab-amr"},
            {"employeeId": "e2", "jiraAccountId": None, "gitHubUserId": "12", "gitHubLogin": "rody"},
            {"employeeId": "e3", "gitHubUserId": "not a number"}])
        self.assertEqual(n, 2)
        self.assertEqual(tx.run.call_args_list[0].kwargs["ids"], [9, 12])
        rows = tx.run.call_args_list[-1].kwargs["rows"]
        self.assertEqual(rows[0]["uid"], "c1:github-user:9")
        self.assertIsNone(rows[1]["jira_account_id"])

    def test_backend_without_endpoint_is_skipped(self):
        from syntrace_ai.workers import knowledge_worker as kw
        backend = mock.Mock()
        backend.identities.return_value = None
        self.assertIsNone(kw.sync_identities(backend, "c1", session_factory=lambda: self.fail("no write")))

    def test_backend_identities_404_is_none(self):
        from syntrace_ai.workers import knowledge_worker as kw
        http = mock.Mock()
        http.request.return_value = mock.Mock(status_code=404)
        self.assertIsNone(kw.Backend("http://b", "k", session=http).identities("c1"))
        http.request.return_value = mock.Mock(status_code=200, json=lambda: {"items": [{"gitHubUserId": 9}]})
        self.assertEqual(kw.Backend("http://b", "k", session=http).identities("c1"), [{"gitHubUserId": 9}])


class FilePathTests(unittest.TestCase):
    def test_one_ticket_lists_changed_files(self):
        commit_row = {"sha": "abc1234", "title": "SYNT-12 login", "date": "2026-11-19", "author": "z", "author_name": None,
                      "keys": ["SYNT-12"], "url": "u", "repo": "o/r", "files": 10, "paths": ["a.cs", "b.cs"],
                      "additions": 1, "deletions": 0}
        text = gg.activity_context({"repos": ["o/r"], "pr_total": 0, "pull_requests": [], "commit_total": 1,
                                    "commits": [commit_row]})
        self.assertIn("files a.cs, b.cs and 8 more", text)

    def test_paths_asked_only_for_one_ticket(self):
        run = mock.Mock(side_effect=lambda q, **p: [] if "WorkItem" in q else [{"total": 0, "items": []}])
        gg.activity(CTX, run, key="SYNT-12")
        self.assertEqual(run.call_args.kwargs["paths"], 8)
        gg.activity(CTX, run)
        self.assertEqual(run.call_args.kwargs["paths"], 0)


class LookupTests(unittest.TestCase):
    def test_number_and_sha_and_repository_filters(self):
        run = mock.Mock(return_value=[{"total": 0, "items": []}])
        gg.activity(CTX, run, number="#65", repository="Spring-Data-Cassandra")
        self.assertEqual(run.call_count, 1)                    # a number means pull requests only
        self.assertEqual((run.call_args.kwargs["number"], run.call_args.kwargs["repo"]), (65, "spring-data-cassandra"))
        run.reset_mock()
        gg.activity(CTX, run, sha="ABC1234")
        self.assertEqual(run.call_count, 1)                    # a sha means commits only
        self.assertEqual(run.call_args.kwargs["sha"], "abc1234")
        self.assertIn("n.sha STARTS WITH $sha", run.call_args.args[0])

    def test_bad_number_or_sha_finds_nothing(self):
        run = mock.Mock()
        self.assertEqual(gg.activity(CTX, run, number="abc")["pr_total"], 0)
        self.assertEqual(gg.activity(CTX, run, sha="xyz!")["commit_total"], 0)
        run.assert_not_called()

    def test_first_step_starts_from_the_pull_request(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(CTX)
        with mock.patch("syntrace_ai.github.github_graph.activity", return_value=AgentTests.RESULT) as act, mock.patch("syntrace_ai.graph.query_engine.run_query"):
            msgs = graph_agent._github_first_step(
                "Who is the Jira assignee of the ticket that pull request #65 in the spring-projects/spring-data-cassandra "
                "repository is for?", walk)
        args = json.loads(msgs[0]["tool_calls"][0]["function"]["arguments"])
        self.assertEqual(args, {"number": 65, "repository": "spring-projects/spring-data-cassandra"})
        self.assertEqual(act.call_args.kwargs["number"], 65)

    def test_first_step_starts_from_the_commit(self):
        from syntrace_ai.assistant import graph_agent
        with mock.patch("syntrace_ai.github.github_graph.activity", return_value=AgentTests.RESULT), mock.patch("syntrace_ai.graph.query_engine.run_query"):
            msgs = graph_agent._github_first_step("Which ticket is commit ABC12345 for?", graph_agent.Walk(CTX))
        self.assertEqual(json.loads(msgs[0]["tool_calls"][0]["function"]["arguments"]), {"sha": "abc12345"})


class FactCheckTests(unittest.TestCase):
    def runner(self, prs=(), commits=0):
        def run(query, **params):
            if "PullRequest" in query:
                return [{"number": n, "repo": repo} for repo, n in prs if n in params["numbers"]]
            return [{"c": commits}]
        return run

    def test_remembered_pull_request_is_caught(self):
        answer = "DATACASS-56 has the pull request https://github.com/spring-projects/spring-data-cassandra/pull/114 (PR #114)."
        self.assertEqual(gg.unverified_claims(answer, CTX, self.runner()), ["#114"])

    def test_pull_request_in_the_graph_passes(self):
        run = self.runner(prs=[("spring-projects/spring-data-cassandra", 65)])
        self.assertEqual(gg.unverified_claims("الـ PR #65 عمله mp911de", CTX, run), [])
        self.assertEqual(gg.unverified_claims(
            "See https://github.com/spring-projects/spring-data-cassandra/pull/65", CTX, run), [])

    def test_link_to_another_repository_is_caught(self):
        run = self.runner(prs=[("tidev/alloy", 769)])
        self.assertEqual(gg.unverified_claims("https://github.com/appcelerator/alloy/pull/769", CTX, run),
                         ["appcelerator/alloy/pull/769"])

    def test_unknown_commit_is_caught(self):
        self.assertEqual(gg.unverified_claims("commit abc1234def was it", CTX, self.runner(commits=0)), ["abc1234def"])
        self.assertEqual(gg.unverified_claims("commit abc1234def was it", CTX, self.runner(commits=1)), [])

    def test_no_access_means_every_claim_is_unverified(self):
        self.assertEqual(gg.unverified_claims("PR #7", AccessContext("c1", ("SYNT",)), mock.Mock()), ["#7"])

    def test_every_path_is_checked(self):
        from syntrace_ai.assistant import answer_generator as ag
        bad = {"status": "ok", "answer": "DATACASS-56 has PR #114.", "links": []}
        with mock.patch.object(ag, "_generate_answer_result", return_value=bad), \
                mock.patch("syntrace_ai.graph.query_engine.run_query", side_effect=self.runner()):
            result = ag.generate_answer_result("Which pull request was opened for DATACASS-56?", CTX)
        self.assertNotIn("114", result["answer"])
        good = {"status": "ok", "answer": "SYNT-12 is Done.", "links": []}
        with mock.patch.object(ag, "_generate_answer_result", return_value=good):
            self.assertIs(ag.generate_answer_result("status of SYNT-12?", CTX), good)   # no GitHub words: untouched


class JiraVsGitHubTests(unittest.TestCase):
    def runner(self, rows, commits=None):
        def run(query, **params):
            if query.startswith("MATCH (c:Commit)"):
                return [{"k": k, "c": n} for k, n in (commits or {}).items() if k in params["keys"]]
            if "key_aliases IS NOT NULL" in query:
                return []
            return rows
        return run

    @staticmethod
    def row(key, done, merged, open_pr=False, number=1):
        return {"key": key, "summary": "s", "status": "Done" if done else "In Progress", "url": "u", "done": done,
                "merged": merged, "open_pr": open_pr,
                "prs": [{"number": number, "state": "open" if open_pr else "closed", "merged": merged,
                         "merged_at": "2020-01-02" if merged else None, "url": "p"}]}

    def test_three_kinds(self):
        rows = [self.row("SYNT-1", True, False), self.row("SYNT-2", False, True), self.row("SYNT-3", True, True, open_pr=True)]
        result = gg.jira_vs_github(CTX, self.runner(rows))
        self.assertEqual(result["counts"], {"done_unmerged": 1, "merged_open": 1, "open_pr_done": 1})
        text = gg.jira_vs_github_context(result)
        self.assertIn("- SYNT-1 | Done", text)
        self.assertIn("PR #1 merged 2020-01-02", text)

    def test_pull_request_applied_by_hand_is_not_a_mismatch(self):
        result = gg.jira_vs_github(CTX, self.runner([self.row("SYNT-1", True, False)], commits={"SYNT-1": 2}))
        self.assertEqual(result["counts"]["done_unmerged"], 0)

    def test_scope(self):
        run = mock.Mock()
        self.assertEqual(gg.jira_vs_github(AccessContext("c1", ("SYNT",)), run)["counts"]["merged_open"], 0)
        self.assertEqual(gg.jira_vs_github(CTX, run, project="HR")["counts"]["merged_open"], 0)   # not allowed
        run.assert_not_called()

    def test_tool(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(CTX)
        with mock.patch("syntrace_ai.github.github_graph.jira_vs_github", return_value={"counts": {"done_unmerged": 0, "merged_open": 0,
                                                                                "open_pr_done": 0}, "items": {}}), \
                mock.patch("syntrace_ai.graph.query_engine.run_query"):
            self.assertIn("agree", walk.jira_vs_github({}))
        self.assertIn("jira_vs_github", {t["function"]["name"] for t in graph_agent.TOOLS})


class RoutingTests(unittest.TestCase):
    def test_count_about_pull_requests_goes_to_the_agent(self):
        from syntrace_ai.assistant import answer_generator as ag
        with mock.patch("syntrace_ai.assistant.intent.route", return_value=None), \
                mock.patch.object(ag, "answer_key_question", return_value=[{"type": "no_key_found"}]), \
                mock.patch.object(ag, "_complete", return_value='{"kind":"aggregate","list_tickets":false}'), \
                mock.patch.object(ag, "_aggregate_result", side_effect=AssertionError("Jira count used")), \
                mock.patch.object(ag, "_agent_result", return_value={"status": "ok", "answer": "3", "links": []}) as agent:
            ag.generate_answer_result("How many DATACASS tickets are done in Jira but have no merged pull request?", CTX)
        agent.assert_called_once()

    def test_plain_jira_count_stays_aggregate(self):
        from syntrace_ai.assistant import answer_generator as ag
        with mock.patch("syntrace_ai.assistant.intent.route", return_value=None), \
                mock.patch.object(ag, "answer_key_question", return_value=[{"type": "no_key_found"}]), \
                mock.patch.object(ag, "_complete", return_value='{"kind":"aggregate"}'), \
                mock.patch.object(ag, "_aggregate_result", return_value={"status": "ok", "answer": "5", "links": []}) as agg:
            ag.generate_answer_result("How many DATACASS tickets are done?", CTX)
        agg.assert_called_once()


class PrNumberTests(unittest.TestCase):
    def walk(self, prs):
        from syntrace_ai.assistant import graph_agent
        w = graph_agent.Walk(CTX)
        w.prs_by = prs
        return w

    def test_number_added_next_to_the_author(self):
        from syntrace_ai.assistant import graph_agent
        w = self.walk({"cb1kenobi": {337}})
        self.assertEqual(graph_agent._with_pr_numbers("الـ PR للـ DAEMON-263 عمله **cb1kenobi**.", w),
                         "الـ PR للـ DAEMON-263 عمله **cb1kenobi (PR #337)**.")

    def test_left_alone_when_named_or_ambiguous(self):
        from syntrace_ai.assistant import graph_agent
        self.assertEqual(graph_agent._with_pr_numbers("PR #337 by cb1kenobi", self.walk({"cb1kenobi": {337}})),
                         "PR #337 by cb1kenobi")
        self.assertEqual(graph_agent._with_pr_numbers("by mp911de", self.walk({"mp911de": {65, 78}})), "by mp911de")


class EdgeCaseTests(unittest.TestCase):
    def test_keys_of_other_projects_are_hidden(self):
        self.assertEqual(gg.visible_keys(["SYNT-12", "HR-3", "SYNT-14"], CTX), ["SYNT-12", "SYNT-14"])
        self.assertEqual(gg.visible_keys(None, CTX), [])

    def test_moved_ticket_brings_its_old_keys(self):
        run = mock.Mock(return_value=[{"key": "SYNT-40", "project": "SYNT", "aliases": ["OLD-7", "SYNT-40"]}])
        self.assertEqual(gg._all_keys(CTX, run, "OLD-7"), ["SYNT-40", "OLD-7"])

    def test_ticket_moved_to_a_hidden_project_is_hidden(self):
        run = mock.Mock(return_value=[{"key": "HR-9", "project": "HR", "aliases": ["SYNT-12"]}])
        self.assertEqual(gg._all_keys(CTX, run, "SYNT-12"), [])

    def test_ticket_not_in_the_graph_keeps_its_key_when_allowed(self):
        run = mock.Mock(return_value=[])
        self.assertEqual(gg._all_keys(CTX, run, "SYNT-77"), ["SYNT-77"])
        self.assertEqual(gg._all_keys(CTX, run, "HR-1"), [])

    def test_activity_searches_every_key_of_a_moved_ticket(self):
        def run(query, **params):
            if "WorkItem" in query:
                return [{"key": "SYNT-40", "project": "SYNT", "aliases": ["OLD-7"]}]
            return [{"total": 0, "items": []}]
        calls = []
        gg.activity(CTX, lambda q, **p: calls.append(p) or run(q, **p), key="SYNT-40")
        self.assertEqual(calls[1]["keys"], ["SYNT-40", "OLD-7"])

    def test_code_search_without_embeddings_still_finds_named_files(self):
        def run(query, **params):
            if "HAS_CHUNK" in query:
                return [{"path": "src/StatementBuilder.java", "start_line": 1, "end_line": 60, "text": "x", "url": "u"}]
            raise AssertionError("vectors should not be needed")

        def down(texts):
            raise RuntimeError("Ollama is down")
        gg._VECTORS.clear()
        with mock.patch.object(gg, "_by_meaning", side_effect=RuntimeError("Ollama is down")):
            hits = gg.search_code("Where is StatementBuilder?", CTX, run, embed=down)
            self.assertEqual([h["path"] for h in hits], ["src/StatementBuilder.java"])
            with self.assertRaises(RuntimeError):     # nothing named: the failure is reported, not hidden
                gg.search_code("where is the login", CTX, run, embed=down)

    def test_unchanged_text_is_not_embedded_again(self):
        tx = FakeTx()
        gg.apply_event(tx, commit(3))
        query, params = next((q, p) for q, p in tx.queries if "MERGE (n:Commit" in q)
        self.assertIn("n.needs_embedding = coalesce(n.embedded_hash, '') <> coalesce(n.embed_hash, '')", query)
        self.assertEqual(len(params["props"]["embed_hash"]), 40)
        self.assertNotIn("needs_embedding", params["props"])
        tx2 = FakeTx()
        gg.apply_event(tx2, commit(4))
        self.assertEqual(next(p for q, p in tx2.queries if "MERGE (n:Commit" in q)["props"]["embed_hash"],
                         params["props"]["embed_hash"])   # same text, same hash

    def test_repository_moved_to_another_project_moves_everything(self):
        class Tx(FakeTx):
            def run(self, query, **params):
                if query.startswith("MATCH (r:GitHubRepository {uid: $uid}) RETURN r.syntrace_project_id"):
                    self.queries.append((query, params))
                    result = mock.Mock()
                    result.single.return_value = {"p": "p-old", "sv": 2}
                    return result
                return super().run(query, **params)
        tx = Tx()
        gg.apply_event(tx, commit(5))                        # projectId p1, newer than the binding's scope
        moved = [p for q, p in tx.queries if "SET n.syntrace_project_id = $p" in q]
        self.assertEqual(len(moved), len(gg.GITHUB_LABELS))
        self.assertTrue(all(p["p"] == "p1" for p in moved))
        tx = Tx()
        gg.apply_event(tx, commit(1))                        # older than the move: keeps the newer project
        self.assertFalse([p for q, p in tx.queries if "SET n.syntrace_project_id = $p" in q])
        props = next(p for q, p in tx.queries if "MERGE (n:Commit" in q)["props"]
        self.assertEqual(props["syntrace_project_id"], "p-old")


class CodeProgressTests(unittest.TestCase):
    def runner(self, children, prs=(), commits=()):
        def run(query, **params):
            if query.startswith("MATCH (w:WorkItem"):
                return [{"key": "SYNT-1", "summary": "Login epic", "type": "Epic", "status": "In Progress",
                         "category": "indeterminate", "aliases": None, "children": children}]
            if "PullRequest" in query:
                return list(prs)
            return list(commits)
        return run

    def child(self, key, category="done", aliases=None):
        return {"key": key, "summary": key, "type": "Sub-task", "status": "Done" if category == "done" else "To Do",
                "category": category, "aliases": aliases}

    def test_rolls_children_up(self):
        children = [self.child("SYNT-2"), self.child("SYNT-3", "new"), self.child("SYNT-4", aliases=["OLD-9"]),
                    self.child("SYNT-5", "new")]
        prs = [{"number": 7, "title": "t", "state": "closed", "merged": True, "merged_at": "2026-11-01", "url": "u",
                "keys": ["SYNT-2"], "repo": "o/r"},
               {"number": 8, "title": "t", "state": "open", "merged": False, "merged_at": None, "url": "u",
                "keys": ["SYNT-3"], "repo": "o/r"}]
        commits = [{"k": "OLD-9", "n": 2}]                   # a moved subtask: its commits named the old key
        result = gg.code_progress(CTX, self.runner(children, prs, commits), "SYNT-1")
        self.assertEqual(result["totals"], {"tickets": 5, "done_in_jira": 2, "merged": 1, "open_pr": 1,
                                            "commits_only": 1, "no_code": 2})
        text = gg.code_progress_context(result)
        self.assertIn("SYNT-1 (Epic, In Progress)", text)
        self.assertIn("- SYNT-2 | Sub-task | Done | SYNT-2 | PR #7 merged 2026-11-01", text)
        self.assertIn("- SYNT-4 | Sub-task | Done | SYNT-4 | 2 commits", text)
        self.assertIn("- SYNT-5 | Sub-task | To Do | SYNT-5 | no code yet", text)

    def test_hidden_or_unknown_ticket(self):
        self.assertIsNone(gg.code_progress(CTX, mock.Mock(return_value=[]), "SYNT-1"))
        self.assertIsNone(gg.code_progress(AccessContext("c1", ("SYNT",)), mock.Mock(), "SYNT-1"))
        self.assertIsNone(gg.code_progress(CTX, mock.Mock(), "not a key"))

    def test_epic_question_starts_with_code_progress(self):
        from syntrace_ai.assistant import graph_agent
        with mock.patch("syntrace_ai.github.github_graph.code_progress", return_value=None), mock.patch("syntrace_ai.graph.query_engine.run_query"):
            msgs = graph_agent._github_first_step("How far is epic SYNT-1 in the code?", graph_agent.Walk(CTX))
            self.assertEqual(msgs[0]["tool_calls"][0]["function"]["name"], "code_progress")
            msgs = graph_agent._github_first_step("الإبيك SYNT-1 وصل لفين في الكود؟", graph_agent.Walk(CTX))
            self.assertEqual(msgs[0]["tool_calls"][0]["function"]["name"], "code_progress")


class StuckPullRequestTests(unittest.TestCase):
    def test_idle_days_means_open_pull_requests_untouched_since(self):
        run = mock.Mock(return_value=[{"total": 0, "items": []}])
        gg.activity(CTX, run, idle_days=7)
        self.assertEqual(run.call_count, 1)                       # pull requests only
        params = run.call_args.kwargs
        self.assertEqual(params["state"], "open")
        self.assertTrue(params["idle_before"] < gg._since(6))
        self.assertIn("<= $idle_before", run.call_args.args[0])


class TicketFamilyTests(unittest.TestCase):
    ROWS = [{"key": "SYNT-12", "type": "Sub-task", "status": "Done", "summary": "Google button",
             "above": [{"key": "SYNT-1", "type": "Epic", "status": "In Progress", "summary": "Login", "depth": 2},
                       {"key": "SYNT-10", "type": "Story", "status": "In Progress", "summary": "Google login", "depth": 1}],
             "under": []},
            {"key": "SYNT-10", "type": "Story", "status": "In Progress", "summary": "Google login",
             "above": [], "under": [{"key": "SYNT-13", "type": "Sub-task", "status": "To Do", "summary": "x"},
                                    {"key": "SYNT-12", "type": "Sub-task", "status": "Done", "summary": "y"}]}]

    def test_chain_up_and_children_down(self):
        family = gg.ticket_family(CTX, mock.Mock(return_value=self.ROWS), ["SYNT-12", "SYNT-10", "bad key"])
        self.assertEqual([a["key"] for a in family[0]["above"]], ["SYNT-10", "SYNT-1"])   # nearest first
        text = gg.ticket_family_context(family)
        self.assertIn("Ticket: SYNT-12 (Sub-task, Done) under SYNT-10 (Story, In Progress: Google login) "
                      "under SYNT-1 (Epic, In Progress: Login)", text)
        self.assertIn("SYNT-10 has 2 tickets under it: SYNT-12 (Sub-task, Done); SYNT-13 (Sub-task, To Do)", text)

    def test_scope_and_bad_keys(self):
        run = mock.Mock(return_value=[])
        self.assertEqual(gg.ticket_family(CTX, run, ["nope"]), [])
        run.assert_not_called()
        gg.ticket_family(CTX, run, ["SYNT-12"])
        self.assertEqual(run.call_args.kwargs["allowed"], ["SYNT"])

    def test_commit_lookup_brings_the_family(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(CTX)
        result = dict(AgentTests.RESULT, pull_requests=[], pr_total=0, commit_total=1, commits=[{
            "sha": "abc1234", "title": "t", "date": "2026-11-19", "author": "z", "author_name": None,
            "keys": ["SYNT-12"], "url": "u", "repo": "o/r", "files": 1, "paths": [], "additions": 1, "deletions": 0}])
        with mock.patch("syntrace_ai.github.github_graph.activity", return_value=result), \
                mock.patch("syntrace_ai.github.github_graph.ticket_family", return_value=gg.ticket_family(
                    CTX, mock.Mock(return_value=self.ROWS[:1]), ["SYNT-12"])), \
                mock.patch("syntrace_ai.graph.query_engine.run_query"):
            text = walk.github_activity({"sha": "abc1234"})
        self.assertIn("under SYNT-1 (Epic", text)
        self.assertIn("SYNT-1", walk.urls)                    # the reply may name the epic


class DateRangeTests(unittest.TestCase):
    def test_month_and_day(self):
        self.assertEqual(gg._day("2015-01"), "2015-01-01T00:00:00Z")
        self.assertEqual(gg._day("2015-01", end=True), "2015-01-31T23:59:59Z")
        self.assertEqual(gg._day("2015-12", end=True), "2015-12-31T23:59:59Z")
        self.assertEqual(gg._day("2016-02-29", end=True), "2016-02-29T23:59:59Z")
        self.assertIsNone(gg._day("January 2015"))
        self.assertIsNone(gg._day("2015-13"))

    def test_merged_in_a_month(self):
        run = mock.Mock(return_value=[{"total": 0, "items": []}])
        gg.activity(CTX, run, state="merged", from_date="2015-01", to_date="2015-01", kind="pull_request")
        p = run.call_args.kwargs
        self.assertEqual((p["from"], p["to"]), ("2015-01-01T00:00:00Z", "2015-01-31T23:59:59Z"))
        self.assertIn("THEN n.merged_at ELSE n.created_at END >= $from", run.call_args.args[0])

    def test_unreadable_date_finds_nothing(self):
        run = mock.Mock()
        self.assertEqual(gg.activity(CTX, run, from_date="last winter")["pr_total"], 0)
        run.assert_not_called()


class ProjectAsRepositoryTests(unittest.TestCase):
    def test_jira_project_name_means_its_repositories(self):
        calls = []

        def run(query, **params):
            calls.append((query, params))
            if "RETURN DISTINCT n.binding_id" in query:
                return [{"b": "b1"}]
            return [{"total": 0, "items": []}]
        gg.activity(CTX, run, repository="synt", state="merged", kind="pull_request")
        last = calls[-1][1]
        self.assertEqual((last["repo"], last["bindings"]), (None, ["b1"]))
        self.assertEqual(calls[0][1]["prefix"], "SYNT-")

    def test_a_real_repository_name_is_kept(self):
        run = mock.Mock(return_value=[{"total": 0, "items": []}])
        gg.activity(CTX, run, repository="spring-data-cassandra", kind="pull_request")
        self.assertEqual(run.call_args.kwargs["repo"], "spring-data-cassandra")
        self.assertIsNone(run.call_args.kwargs["bindings"])

    def test_jira_project_in_text_means_its_repositories(self):
        # the model wrote "DAEMON pull requests" as text="DAEMON": that would match titles, not the project
        calls = []

        def run(query, **params):
            calls.append((query, params))
            if "RETURN DISTINCT n.binding_id" in query:
                return [{"b": "b1"}]
            return [{"total": 0, "items": []}]
        gg.activity(CTX, run, text="synt", state="merged", from_date="2020-09-01", to_date="2020-09-30")
        last = calls[-1][1]
        self.assertEqual((last["text"], last["repo"], last["bindings"]), (None, None, ["b1"]))

    def test_ordinary_text_is_kept(self):
        run = mock.Mock(return_value=[{"total": 0, "items": []}])
        gg.activity(CTX, run, text="optimistic locking", kind="pull_request")
        self.assertEqual(run.call_args.kwargs["text"], "optimistic locking")
        self.assertIsNone(run.call_args.kwargs["bindings"])

    def test_project_without_repositories_finds_nothing(self):
        run = mock.Mock(return_value=[])
        self.assertEqual(gg.activity(CTX, run, repository="SYNT")["pr_total"], 0)


class IndexingStatusTests(unittest.TestCase):
    def runner(self, repos, counts):
        def run(query, **params):
            if query.startswith("MATCH (r:GitHubRepository)"):
                return repos
            label = query.split("(n:")[1].split(")")[0]
            return [dict(b=b, total=t, waiting=w) for (b, lab), (t, w) in counts.items() if lab == label]
        return run

    def repo(self, binding, name, last_sync="2026-11-20T10:00:00Z", skipped=0, reasons=None):
        return {"binding": binding, "repo": name, "last_sync": last_sync, "head": "c" * 40, "prepared": 500,
                "skipped": skipped, "reasons": reasons or []}

    def test_each_status(self):
        repos = [self.repo("b1", "o/ready"), self.repo("b2", "o/partial", skipped=292, reasons=["code_snapshot_limit"]),
                 self.repo("b3", "o/indexing"), self.repo("b4", "o/new", last_sync=None)]
        counts = {("b1", "Commit"): (380, 0), ("b1", "CodeChunk"): (900, 0), ("b2", "CodeFile"): (500, 0),
                  ("b3", "CodeChunk"): (10, 4)}
        rows = gg.indexing_status(CTX, self.runner(repos, counts))
        self.assertEqual([r["status"] for r in rows], ["ready", "partial", "embedding", "not_synced"])
        self.assertEqual(rows[0]["commits"], 380)
        text = gg.indexing_status_context(rows)
        self.assertIn("o/partial: synced, some files not indexed", text)
        self.assertIn("292 files not indexed (over the 500 files / 8 MB snapshot limit)", text)
        self.assertIn("4 items waiting to be searchable", text)
        self.assertIn("o/new: first sync not finished yet", text)

    def test_scope(self):
        run = mock.Mock()
        self.assertEqual(gg.indexing_status(AccessContext("c1", ("SYNT",)), run), [])
        run.assert_not_called()
        self.assertEqual(gg.indexing_status_context([]), "No GitHub repository is connected to these projects.")

    def test_tool(self):
        from syntrace_ai.assistant import graph_agent
        walk = graph_agent.Walk(CTX)
        with mock.patch("syntrace_ai.github.github_graph.indexing_status", return_value=[]), mock.patch("syntrace_ai.graph.query_engine.run_query"):
            self.assertIn("No GitHub repository", walk.github_status({}))
        self.assertIn("github_status", {t["function"]["name"] for t in graph_agent.TOOLS})


class CoverageTests(unittest.TestCase):
    """SYNT-720: what GitHub did not give in full is said, not hidden."""

    def test_incomplete_file_list_is_marked(self):
        item = {"paths": ["a.cs"], "files": 300, "partial": True}
        self.assertEqual(gg._paths(item), " | files a.cs and 299 more (the list GitHub gave is incomplete)")
        self.assertEqual(gg._paths({"paths": [], "files": 0, "partial": True}), " | file list incomplete")
        self.assertEqual(gg._paths({"paths": [], "files": 3}), "")

    def test_backend_exclusions_are_not_indexed(self):
        # The backend sends only allowed code; a file event without a path is refused, not stored half-way.
        bad = code_file(4)
        bad["payload"]["path"] = ""
        with self.assertRaises(gg.BadEvent):
            gg.apply_event(FakeTx(), bad)

    def test_each_chunk_cites_its_lines(self):
        parts = gg.chunks("\n".join(f"l{i}" for i in range(1, 61)), "a.py", "https://github.com/o/r/blob/h/a.py#L1-L60")
        self.assertEqual(parts[0]["url"], "https://github.com/o/r/blob/h/a.py#L1-L60")


class NamedProjectTests(unittest.TestCase):
    """The question names one Jira project and the model's GitHub call names none: stay in that project."""

    def test_named_projects(self):
        from syntrace_ai.assistant import graph_agent as ga
        ctx = AccessContext("c1", ("BE", "DAEMON", "ALOY"), None, ("p1",))
        self.assertEqual(ga._named_projects("Which BE pull requests were merged in January 2020?", ctx), ["BE"])
        self.assertEqual(ga._named_projects("who made the PR for BE-706", ctx), [])
        self.assertEqual(ga._named_projects("what will be merged next", ctx), [])
        self.assertEqual(ga._named_projects("ALOY and BE pull requests", ctx), ["ALOY", "BE"])

    def _call(self, question, arguments):
        from syntrace_ai.assistant import graph_agent as ga
        ctx = AccessContext("c1", ("BE", "DAEMON"), None, ("p1",))
        walk = ga.Walk(ctx, question)
        empty = {"pull_requests": [], "commits": [], "pr_total": 0, "commit_total": 0, "repos": []}
        with mock.patch("syntrace_ai.github.github_graph.activity", return_value=empty) as act:
            walk.github_activity(arguments)
        return act.call_args.kwargs

    def test_dropped_project_is_added(self):
        kw = self._call("Which BE pull requests were merged in January 2020?",
                        {"state": "merged", "from_date": "2020-01-01", "to_date": "2020-01-31"})
        self.assertEqual(kw["repository"], "BE")

    def test_given_filters_are_kept(self):
        kw = self._call("Which BE pull requests mention retries?", {"text": "retries"})
        self.assertIsNone(kw["repository"])
        kw = self._call("Which BE and DAEMON pull requests were merged?", {"state": "merged"})
        self.assertIsNone(kw["repository"])
