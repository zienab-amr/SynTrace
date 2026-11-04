"""Read-only: why might queries see nothing? Prints the scope from .env and what the graph holds.
Never prints the password and never writes to the database."""
import os
import sys

from dotenv import load_dotenv
from neo4j import GraphDatabase

load_dotenv()

tenant = os.getenv("TENANT_ID")
allowed = [p.strip().upper() for p in (os.getenv("ALLOWED_PROJECTS") or "").split(",") if p.strip()]
print(f"NEO4J_URI        = {os.getenv('NEO4J_URI')}")
print(f"TENANT_ID        = {tenant}")
print(f"ALLOWED_PROJECTS = {allowed}")
print(f"JIRA_SITE_ID     = {os.getenv('JIRA_SITE_ID')}")
print(f"JIRA_BASE_URL    = {os.getenv('JIRA_BASE_URL')}\n")

driver = GraphDatabase.driver(os.getenv("NEO4J_URI"),
                              auth=(os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASSWORD")))
try:
    with driver.session() as session:
        rows = list(session.run(
            "MATCH (w:WorkItem) RETURN w.tenant_id AS tenant, w.jira_site_id AS site, "
            "w.project_key AS project, count(*) AS total, count(w.summary) AS complete, "
            "count(w.embedding) AS embedded ORDER BY tenant, site, project"))
finally:
    driver.close()

if not rows:
    print("The graph has NO WorkItems.\n-> Run: python build_graph.py")
    sys.exit(0)
for r in rows:
    print(f"tenant={r['tenant']} site={r['site']} project={r['project']}: "
          f"{r['total']} items, {r['complete']} complete, {r['embedded']} with embeddings")
print()
tenants = {r["tenant"] for r in rows}
projects = {r["project"] for r in rows if r["tenant"] == tenant}
if tenant not in tenants:
    print(f"-> TENANT_ID '{tenant}' is not in the graph. It holds: {sorted(map(str, tenants))}")
elif not allowed:
    print(f"-> ALLOWED_PROJECTS is empty, so queries see nothing. "
          f"For this graph: ALLOWED_PROJECTS={','.join(sorted(map(str, projects)))}")
elif not projects & set(allowed):
    print(f"-> ALLOWED_PROJECTS does not match the graph's projects: {sorted(map(str, projects))}")
else:
    print("-> Scope and data match.")
