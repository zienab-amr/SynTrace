"""
verify_graph.py
بيقارن الـ graph في Neo4j بملفات الـ JSON (المصدر الحقيقي) من غير ما يعدّل فيه أي حاجة.
مفيش أرقام ثابتة: كل التوقعات بتتحسب من الملفات، فبيفضل شغال لما المشاريع تزيد.

  python verify_graph.py [--dir all_tickets] [--tenant syntrace]
المتوقع: كل السطور PASS (WARN مش بيفشّل).
"""
import argparse
import glob
import json
import os

from dotenv import load_dotenv
from neo4j import GraphDatabase

from ingest import STRUCTURAL_REL_TYPES, rel_type_of

load_dotenv()
ap = argparse.ArgumentParser()
ap.add_argument("--dir", default="all_tickets")
ap.add_argument("--tenant", default=os.getenv("TENANT_ID", "syntrace"))
args = ap.parse_args()
T = args.tenant

driver = GraphDatabase.driver(
    os.getenv("NEO4J_URI"), auth=(os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASSWORD")))
passed = failed = warned = 0


def q(query, **p):
    with driver.session() as s:
        return list(s.run(query, **p))


def check(name, ok, detail=""):
    global passed, failed
    if ok:
        passed += 1
        print(f"PASS  {name}")
    else:
        failed += 1
        print(f"FAIL  {name}  {detail}")


def warn(name, ok, detail=""):
    global warned
    if ok:
        print(f"PASS  {name}")
    else:
        warned += 1
        print(f"WARN  {name}  {detail}")


# ---- الحقيقة من الملفات ----
issues = {}
for path in glob.glob(os.path.join(args.dir, "*.json")):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    issues[d["key"]] = d
print(f"الحقيقة من الملفات: {len(issues)} تذكرة\n")

exp_links, exp_child = set(), set()
exp_comments = exp_worklogs = exp_attachments = exp_changes = 0
for key, d in issues.items():
    fl = d["fields"]
    for link in fl.get("issuelinks") or []:
        rel = rel_type_of(link["type"]["outward"])
        if "outwardIssue" in link:
            exp_links.add((rel, key, link["outwardIssue"]["key"]))
        elif "inwardIssue" in link:
            exp_links.add((rel, link["inwardIssue"]["key"], key))
    if fl.get("parent"):
        exp_child.add((key, fl["parent"]["key"]))
    for s in fl.get("subtasks") or []:
        exp_child.add((s["key"], key))
    exp_comments += len((fl.get("comment") or {}).get("comments") or [])
    exp_worklogs += len((fl.get("worklog") or {}).get("worklogs") or [])
    exp_attachments += len(fl.get("attachment") or [])
    for h in (d.get("changelog") or {}).get("histories") or []:
        exp_changes += len(h.get("items") or [])

# ---- أعداد ----
n = q("MATCH (w:WorkItem {tenant_id: $t}) WHERE w.summary IS NOT NULL RETURN count(w) AS n", t=T)[0]["n"]
check(f"{len(issues)} تذكرة كاملة في الـ graph", n == len(issues), f"found {n}")

bad = q("MATCH (n) WHERE n.uid IS NULL OR n.tenant_id IS NULL RETURN labels(n) AS l, count(*) AS c")
check("كل node ليه uid و tenant_id", not bad, str([(r['l'], r['c']) for r in bad]))
bad = q("MATCH (w:WorkItem) WHERE w.project_key IS NULL RETURN w.key LIMIT 5")
check("كل WorkItem ليه project_key", not bad)

# ---- links ----
rows = q("MATCH (a:WorkItem {tenant_id: $t})-[r]->(b:WorkItem) WHERE NOT type(r) IN $s "
         "RETURN type(r) AS t, a.key AS a, b.key AS b", t=T, s=STRUCTURAL_REL_TYPES)
got_links = {(r["t"], r["a"], r["b"]) for r in rows}
check(f"الـ links مطابقة للملفات ({len(exp_links)})", got_links == exp_links,
      f"ناقص={sorted(exp_links - got_links)[:5]} زيادة={sorted(got_links - exp_links)[:5]}")
check("مفيش IS_BLOCKED_BY (القديمة المعكوسة)", not any(t == "IS_BLOCKED_BY" for t, _, _ in got_links))
check("مفيش BLOCKS في الاتجاهين بين نفس التذكرتين",
      not q("MATCH (a)-[:BLOCKS]->(b)-[:BLOCKS]->(a) RETURN a LIMIT 1"))
check("مفيش علاقة بتشاور على نفسها", not q("MATCH (a)-[r]->(a) RETURN a LIMIT 1"))

# ---- parent / subtasks ----
rows = q("MATCH (c:WorkItem {tenant_id: $t})-[:CHILD_OF]->(p:WorkItem) RETURN c.key AS c, p.key AS p", t=T)
got_child = {(r["c"], r["p"]) for r in rows}
check(f"CHILD_OF مطابقة للملفات ({len(exp_child)})", got_child == exp_child,
      f"ناقص={sorted(exp_child - got_child)[:5]} زيادة={sorted(got_child - exp_child)[:5]}")
check("كل تذكرة ليها parent واحد على الأكتر",
      not q("MATCH (c:WorkItem)-[r:CHILD_OF]->() WITH c, count(r) AS n WHERE n > 1 RETURN c.key LIMIT 5"))

# ---- assignee ----
rows = q("MATCH (w:WorkItem {tenant_id: $t}) OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(p:Person) "
         "RETURN w.key AS k, collect(p.displayName) AS names", t=T)
graph_assignee = {r["k"]: r["names"] for r in rows}
mismatch = []
for key, d in issues.items():
    a = (d["fields"].get("assignee") or {}).get("displayName")
    names = graph_assignee.get(key, [])
    if (a is None and names) or (a is not None and names != [a]):
        mismatch.append((key, a, names))
check("الـ assignee مطابق للملفات (وunassigned = مفيش edge)", not mismatch, str(mismatch[:3]))

# ---- events ----
for label, exp in (("Comment", exp_comments), ("Worklog", exp_worklogs), ("Attachment", exp_attachments)):
    n = q(f"MATCH (n:{label} {{tenant_id: $t}}) RETURN count(n) AS n", t=T)[0]["n"]
    if label == "Comment":
        check(f"{label}: {exp} من الملفات", n >= exp, f"found {n}")  # >= لأن الـ webhook بيضيف
    else:
        warn(f"{label}: {exp} من الملفات", n >= exp, f"found {n}")
n = q("MATCH (c:ChangeEvent {tenant_id: $t}) RETURN count(c) AS n", t=T)[0]["n"]
if exp_changes:
    check(f"ChangeEvents: {exp_changes} من الـ changelog", n >= exp_changes, f"found {n}")
else:
    warn("الملفات من غير changelog (شغّلي local export refresh عشان الـ Assignment History)", False)

# ---- خصوصية / تصميم ----
check("مفيش إيميلات متخزنة على Person",
      q("MATCH (p:Person) WHERE p.email IS NOT NULL RETURN count(p) AS n")[0]["n"] == 0)
check("مفيش lifecycle_status (قرار الدكتور: مسح فعلي)",
      q("MATCH (n) WHERE n.lifecycle_status IS NOT NULL RETURN count(n) AS n")[0]["n"] == 0)
check("مفيش علاقات بين tenants مختلفة",
      not q("MATCH (a)-[r]->(b) WHERE a.tenant_id <> b.tenant_id RETURN a LIMIT 1"))
warn("مفيش stubs (تذاكر مرجعية من غير بيانات)",
     not q("MATCH (w:WorkItem {tenant_id: $t}) WHERE w.summary IS NULL RETURN w.key LIMIT 5", t=T),
     "(تذاكر من مشاريع ما اتنزلتش، أو اتمسحت)")

# ---- stable identity, lifecycle, and reference integrity ----
duplicate_ids = q(
    "MATCH (w:WorkItem) WHERE w.jira_id IS NOT NULL AND w.jira_site_id IS NOT NULL "
    "WITH w.tenant_id AS tenant, w.jira_site_id AS site, w.jira_id AS jira_id, count(*) AS n "
    "WHERE n > 1 RETURN tenant, site, jira_id, n LIMIT 10")
check("stable tenant/site/Jira-ID uniqueness", not duplicate_ids, str(duplicate_ids))

leftover_tombstones = q("MATCH (d:DeletionTombstone) RETURN d.uid AS uid LIMIT 10")
check("no deletion tombstones are kept", not leftover_tombstones, str(leftover_tombstones))

alias_collisions = q(
    "MATCH (a:WorkItem {tenant_id: $t}), (b:WorkItem {tenant_id: $t}) "
    "WHERE a <> b AND a.jira_site_id = b.jira_site_id "
    "AND (a.key IN coalesce(b.key_aliases, []) OR b.key IN coalesce(a.key_aliases, [])) "
    "RETURN a.key AS a, b.key AS b, a.jira_site_id AS site LIMIT 10", t=T)
check("no current-key/alias collisions within a tenant/site", not alias_collisions,
      str(alias_collisions))

cross_site_edges = q(
    "MATCH (a:WorkItem)-[r]->(b:WorkItem) "
    "WHERE a.tenant_id <> b.tenant_id OR "
    "(a.jira_site_id IS NOT NULL AND b.jira_site_id IS NOT NULL "
    "AND a.jira_site_id <> b.jira_site_id) "
    "RETURN type(r) AS rel, a.uid AS a, b.uid AS b LIMIT 10")
check("no WorkItem relationship crosses tenant or Jira site", not cross_site_edges,
      str(cross_site_edges))

stale_project_edges = q(
    "MATCH (w:WorkItem)-[:BELONGS_TO]->(p:Project) "
    "WHERE w.tenant_id = $t AND (p.tenant_id <> w.tenant_id "
    "OR p.jira_site_id <> w.jira_site_id OR p.key <> w.project_key) "
    "RETURN w.key AS key, w.project_key AS expected, p.key AS actual LIMIT 10", t=T)
check("BELONGS_TO matches the current project and site", not stale_project_edges,
      str(stale_project_edges))

parent_errors = q(
    "MATCH (c:WorkItem {tenant_id: $t})-[r:CHILD_OF]->(p:WorkItem) "
    "WHERE c = p OR c.tenant_id <> p.tenant_id "
    "OR (c.jira_site_id IS NOT NULL AND p.jira_site_id IS NOT NULL "
    "AND c.jira_site_id <> p.jira_site_id) "
    "RETURN c.key AS child, p.key AS parent LIMIT 10", t=T)
check("parent-child references are non-self and site/tenant scoped", not parent_errors,
      str(parent_errors))

for label, rel in (("Comment", "HAS_COMMENT"), ("Attachment", "HAS_ATTACHMENT"),
                   ("Worklog", "HAS_WORKLOG"), ("ChangeEvent", "HAD_CHANGE")):
    orphan = q(
        f"MATCH (n:{label} {{tenant_id: $t}}) OPTIONAL MATCH (w:WorkItem)-[:{rel}]->(n) "
        "WITH n, count(w) AS owners WHERE owners = 0 RETURN count(n) AS n", t=T)[0]["n"]
    warn(f"no orphan {label} nodes", orphan == 0, f"found {orphan}")

for label, pattern, owner in (("Project", "(w:WorkItem)-[:BELONGS_TO]->(n)", "w"),
                              ("Sprint", "(w:WorkItem)-[:IN_SPRINT]->(n)", "w"),
                              ("Person", "(n)-[r]-()", "r")):
    orphan = q(f"MATCH (n:{label} {{tenant_id: $t}}) OPTIONAL MATCH {pattern} "
               f"WITH n, count({owner}) AS owners WHERE owners = 0 "
               "RETURN count(n) AS n", t=T)[0]["n"]
    warn(f"no orphan {label} nodes", orphan == 0, f"found {orphan}")

stale_sources = q(
    "MATCH ()-[r]->() UNWIND coalesce(r.source_issue_uids, []) AS source_uid "
    "OPTIONAL MATCH (w:WorkItem {uid: source_uid}) "
    "WITH r, source_uid, count(w) AS found WHERE found = 0 "
    "RETURN type(r) AS rel, source_uid LIMIT 10")
check("relationship source provenance references live issues", not stale_sources,
      str(stale_sources))

print(f"\n==== {passed} passed, {failed} failed, {warned} warnings ====")
driver.close()
raise SystemExit(1 if failed else 0)
