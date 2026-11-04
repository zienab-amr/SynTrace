"""Test double: an in-memory graph that understands just the
Cypher statements ingest.py issues. It models state ordering, identity and
rollback; it does NOT validate Cypher syntax or Neo4j semantics (see test_neo4j_integration.py)."""
import copy
import re


# ------------------------------------------------------------------ graph
class Result:
    def __init__(self, rows=()):
        self.rows = list(rows)

    def single(self):
        return self.rows[0] if self.rows else None

    def __iter__(self):
        return iter(self.rows)


class GraphTx:
    def __init__(self):
        self.items = {}        # WorkItem uid -> props
        self.projects = {}     # Project uid -> props
        self.entities = {}     # (label, uid) -> props
        self.calls = []

    def snapshot(self):
        return copy.deepcopy((self.items, self.projects, self.entities))

    def restore(self, snap):
        self.items, self.projects, self.entities = copy.deepcopy(snap)

    # helpers for assertions
    def workitems(self):
        return {u: p for u, p in self.items.items() if p.get("summary") is not None or p.get("key")}

    def by_key(self, key):
        return [p for p in self.items.values() if p.get("key") == key]

    def count(self, label):
        return sum(1 for (l, _u) in self.entities if l == label)

    def run(self, query, **p):
        q = " ".join(query.split())
        self.calls.append((q, p))
        return Result(self._dispatch(q, p))

    # ------------------------------------------------------------------
    def _dispatch(self, q, p):
        it = self.items
        if q == "MATCH (w:WorkItem {uid: $uid}) RETURN w.uid AS uid":
            return [{"uid": p["uid"]}] if p["uid"] in it else []
        if q.startswith("MATCH (w:WorkItem {tenant_id: $tenant, jira_id: $jira_id})"):
            return [{"uid": u, "key": n.get("key"), "site": n.get("jira_site_id"),
                     "summary": n.get("summary")} for u, n in it.items()
                    if n.get("tenant_id") == p["tenant"] and n.get("jira_id") == p["jira_id"]
                    and n.get("jira_site_id") in (p["site"], None)]
        if "RETURN w.uid AS uid, w.jira_id AS jira_id, w.key AS key, w.jira_site_id AS site" in q \
                and "{uid: $uid}" in q:
            n = it.get(p["uid"])
            return [{"uid": p["uid"], "jira_id": n.get("jira_id"), "key": n.get("key"),
                     "site": n.get("jira_site_id"), "summary": n.get("summary")}] if n else []
        if "WHERE w.summary IS NULL RETURN" in q:
            return [{"uid": u, "jira_id": n.get("jira_id"), "key": n["key"],
                     "site": n.get("jira_site_id"), "summary": None} for u, n in it.items()
                    if n.get("tenant_id") == p["tenant"] and n.get("key") == p["key"]
                    and n.get("jira_site_id") == p["site"] and n.get("summary") is None]
        if q.startswith("MATCH (w:WorkItem {uid: $uid}) RETURN w.updated AS updated, w.summary"):
            n = it.get(p["uid"])
            if not n:
                return []
            return [{"updated": n.get("updated"), "summary": n.get("summary"), "key": n.get("key"),
                     "project_key": n.get("project_key"),
                     "last_changelog_id": n.get("last_changelog_id"),
                     "state_fp": n.get("state_fp"), "state_fp_mode": n.get("state_fp_mode")}]
        if q.startswith("MERGE (w:WorkItem {uid: $uid}) WITH w, w.key AS prior_key"):
            n = it.setdefault(p["uid"], {"uid": p["uid"]})
            prior = n.get("key")
            n.update(p["props"])
            n["key_aliases"] = [k for k in (n.get("key_aliases") or []) + [prior, p["props"]["key"]]
                                if k and k != p["props"]["key"]]
            n["key_aliases"] = list(dict.fromkeys(n["key_aliases"]))
            return []
        if "SET w.last_changelog_id = CASE" in q:
            n = it[p["uid"]]
            cid = p["cid"]
            if cid is not None and (n.get("last_changelog_id") is None or cid > n["last_changelog_id"]):
                n["last_changelog_id"] = cid
            n["state_fp"], n["state_fp_mode"] = p["fp"], p["mode"]
            for k in ("reconcile_needed", "reconcile_reason", "reconcile_flagged_at",
                      "source_visibility", "source_visibility_checked_at"):
                n.pop(k, None)
            return []
        m = re.match(r"MATCH \(w:WorkItem \{uid: \$uid\}\) REMOVE w\.(\w+)$", q)
        if m:
            it[p["uid"]].pop(m.group(1), None)
            return []
        if "SET w.reconcile_needed = true" in q:
            it[p["uid"]].update(reconcile_needed=True, reconcile_reason=p["reason"])
            return []
        if "SET w.source_visibility = 'unconfirmed_absent'" in q:
            it[p["uid"]]["source_visibility"] = "unconfirmed_absent"
            return []
        # --- projects
        if q == "MATCH (p:Project {uid: $uid}) RETURN p.uid AS uid":
            return [{"uid": p["uid"]}] if p["uid"] in self.projects else []
        if "jira_id: $id}) WHERE p.uid <> $uid RETURN p.uid AS uid, p.key AS key" in q:
            return [{"uid": u, "key": n["key"]} for u, n in self.projects.items()
                    if n.get("jira_id") == p["id"] and u != p["uid"]]
        if q.startswith("MATCH (p:Project {tenant_id: $t, jira_site_id: $s, jira_id: $id}) RETURN p.key"):
            return [{"key": n["key"]} for n in self.projects.values() if n.get("jira_id") == p["id"]]
        if q.startswith("MATCH (p:Project {uid: $old}) SET p.uid = $uid, p.key = $key"):
            n = self.projects.pop(p["old"])
            n.update(uid=p["uid"], key=p["key"],
                     key_aliases=list(dict.fromkeys((n.get("key_aliases") or []) + [p["old_key"]])))
            self.projects[p["uid"]] = n
            return []
        if "SET w.project_key = $key" in q and "project_key: $old_key" in q:
            for n in it.values():
                if n.get("project_key") == p["old_key"] and n.get("jira_site_id") == p["s"]:
                    n["project_key"] = p["key"]
            return []
        if q.startswith("MERGE (pr:Project {uid: $puid}) SET pr += $pprops"):
            self.projects.setdefault(p["puid"], {}).update(p["pprops"])
            return []
        if q.startswith("MERGE (p:Project {uid: $uid}) SET p += $props"):
            self.projects.setdefault(p["uid"], {}).update(p["props"])
            return []
        if q.startswith("MATCH (p:Project {tenant_id: $tenant, jira_site_id: $site, key: $key}) DETACH DELETE p"):
            for u in [u for u, n in self.projects.items() if n.get("key") == p["key"]]:
                del self.projects[u]
            return []
        if q.startswith("MATCH (w:WorkItem {uid: $old_uid}) SET w.uid = $uid"):
            node = it.pop(p["old_uid"], None)
            if node is not None:
                node.update(uid=p["uid"], jira_site_id=p["site"], jira_id=p["jira_id"])
                it[p["uid"]] = node
            return []
        # --- stubs
        if "x.key = $key OR $key IN coalesce(x.key_aliases" in q:
            return [{"uid": u} for u, n in it.items()
                    if n.get("tenant_id") == p["tenant"] and n.get("jira_site_id") == p["site"]
                    and (n.get("key") == p["key"] or p["key"] in (n.get("key_aliases") or []))][:1]
        if q.startswith("MATCH (x:WorkItem {uid: $uid}) RETURN x.uid AS uid, x.jira_site_id"):
            return []
        if q.startswith("MERGE (x:WorkItem {uid: $uid}) ON CREATE SET x.key = $key"):
            it.setdefault(p["uid"], {"uid": p["uid"], "key": p["key"], "tenant_id": p["tenant"],
                                     "jira_site_id": p["site"], "project_key": p["project"]})
            return []
        # --- entities
        for label, var in (("Comment", "c"), ("Worklog", "w")):
            if q.startswith(f"MATCH ({var}:{label} {{uid: $uid}}) RETURN {var}.updated AS updated"):
                e = self.entities.get((label, p["uid"]))
                return [{"updated": e.get("updated")}] if e else []
            if q.startswith(f"MERGE ({var}:{label} {{uid: $uid}}) SET {var} += $props"):
                self.entities.setdefault((label, p["uid"]), {}).update(p["props"])
                return []
        for label in ("ChangeEvent", "Attachment"):
            if q.startswith(f"MERGE (c:{label} {{uid: $uid}}) SET c += $props") or \
               q.startswith(f"MERGE (a:{label} {{uid: $uid}}) SET a += $props"):
                self.entities.setdefault((label, p["uid"]), {}).update(p["props"])
                return []
        m = re.match(r"MATCH \(n:(\w+) \{uid: \$uid\}\) DETACH DELETE n$", q)
        if m:
            self.entities.pop((m.group(1), p["uid"]), None)
            return []
        # --- deletion
        if "RETURN w.uid AS uid, w.key AS key, w.jira_id AS jira_id, w.jira_site_id AS site_id" in q:
            return [{"uid": u, "key": n.get("key"), "jira_id": n.get("jira_id"),
                     "site_id": n.get("jira_site_id"), "issuetype": n.get("issuetype"),
                     "key_aliases": n.get("key_aliases") or []} for u, n in it.items()
                    if n.get("tenant_id") == p["t"] and n.get("jira_site_id") in (p["site"], None)
                    and (n.get("key") == p["key"] or p["key"] in (n.get("key_aliases") or []))]
        if "RETURN s.key AS k" in q:
            return []
        if q.startswith("MATCH (w:WorkItem {tenant_id: $t, jira_id: $id}) WHERE"):
            return [{"key": n.get("key"), "uid": u} for u, n in it.items()
                    if n.get("tenant_id") == p["t"] and n.get("jira_id") == p["id"]
                    and n.get("jira_site_id") in (p["site"], None)]
        if q.startswith("MATCH (w:WorkItem {uid: $uid}) DETACH DELETE w"):
            it.pop(p["uid"], None)
            return []
        if q.startswith("MATCH (w:WorkItem {tenant_id: $t}) WHERE w.key = $key"):
            for u in [u for u, n in it.items() if n.get("key") == p["key"]]:
                del it[u]
            return []
        if "o.issue_key IN $keys OR o.issue_id = $jira_id" in q or \
           ("o.issue_id = $jira_id" in q and "DETACH DELETE o" in q):
            keys = p.get("keys") or []
            for k in [k for k, e in self.entities.items()
                      if e.get("jira_site_id") == p["site"]
                      and (e.get("issue_key") in keys or (p.get("jira_id") and e.get("issue_id") == p["jira_id"]))]:
                del self.entities[k]
            return []
        if "RETURN w.key AS key" in q and "project_key: $key" in q:
            return [{"key": n["key"]} for n in it.values()
                    if n.get("tenant_id") == p["tenant"] and n.get("jira_site_id") == p["site"]
                    and n.get("project_key") == p["key"]]
        # --- reconcile reads
        if "RETURN w.jira_id AS id, w.uid AS uid, w.key AS key, w.updated AS updated" in q:
            return [{"id": n["jira_id"], "uid": u, "key": n.get("key"), "updated": n.get("updated"),
                     "summary": n.get("summary"), "reconcile_needed": n.get("reconcile_needed"),
                     "last_changelog_id": n.get("last_changelog_id")} for u, n in it.items()
                    if n.get("tenant_id") == p["t"] and n.get("jira_site_id") == p["s"]
                    and n.get("project_key") == p["p"] and n.get("jira_id")]
        if "MATCH (p:Project {tenant_id: $t, jira_site_id: $s}) RETURN p.key AS key" in q:
            return [{"key": n["key"]} for n in self.projects.values()]
        if "SET p.source_visibility" in q:
            for n in self.projects.values():
                if n["key"] == p["k"]:
                    n["source_visibility"] = "unconfirmed_absent"
            return []
        return []   # edges, evidence cleanup, etc.: no state modelled


class FakeSession:
    """execute_write runs fn(tx) with rollback on any exception (as the real driver does)."""
    def __init__(self, tx, fail_plan):
        self.tx, self.fail_plan = tx, fail_plan

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def execute_write(self, fn, *args):
        snap = self.tx.snapshot()
        try:
            if self.fail_plan:
                exc = self.fail_plan.pop(0)
                if exc is not None:
                    # fail AFTER some writes happened, to prove rollback + safe retry
                    self.tx.run("MERGE (w:WorkItem {uid: $uid}) WITH w, w.key AS prior_key SET w += $props",
                                uid="partial-garbage", props={"key": "GARBAGE"})
                    raise exc
            return fn(self.tx, *args)
        except Exception:
            self.tx.restore(snap)
            raise

    execute_read = execute_write


def session_factory(tx, fail_plan=None):
    plan = fail_plan if fail_plan is not None else []
    return lambda: FakeSession(tx, plan)
