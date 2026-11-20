"""
setup_constraints.py
بيشيل الـ constraints القديمة (على key/accountId/id، بتتصادم مع multi-tenancy)
ويعمل constraints على uid + indexes للـ tenant/project. Idempotent.
"""
import os

from dotenv import load_dotenv
from neo4j import GraphDatabase

load_dotenv()

OLD_CONSTRAINTS = ["workitem_key_unique", "person_account_unique",
                   "project_key_unique", "sprint_id_unique"]

UID_LABELS = ["WorkItem", "Person", "Project", "Sprint", "Comment", "Worklog",
              "Attachment", "ChangeEvent", "IssueType", "Board", "FieldCatalog"]

INDEXES = [
    "CREATE INDEX workitem_tenant_key IF NOT EXISTS FOR (n:WorkItem) ON (n.tenant_id, n.key)",
    "CREATE INDEX workitem_tenant_site_key IF NOT EXISTS FOR (n:WorkItem) ON (n.tenant_id, n.jira_site_id, n.key)",
    "CREATE INDEX workitem_project IF NOT EXISTS FOR (n:WorkItem) ON (n.tenant_id, n.project_key)",
    "CREATE INDEX workitem_jira_id IF NOT EXISTS FOR (n:WorkItem) ON (n.tenant_id, n.jira_site_id, n.jira_id)",
    "CREATE INDEX project_tenant_key IF NOT EXISTS FOR (n:Project) ON (n.tenant_id, n.key)",
    "CREATE INDEX change_issue IF NOT EXISTS FOR (n:ChangeEvent) ON (n.issue_key)",
]

WORKITEM_IDENTITY_CONSTRAINT = (
    "CREATE CONSTRAINT workitem_tenant_site_jira_unique IF NOT EXISTS "
    "FOR (n:WorkItem) REQUIRE (n.tenant_id, n.jira_site_id, n.jira_id) IS UNIQUE"
)


def validate_identity_data(session):
    rows = list(session.run(
        "MATCH (w:WorkItem) WHERE w.tenant_id IS NULL OR w.uid IS NULL "
        "RETURN w.key AS key LIMIT 5"))
    if rows:
        raise RuntimeError(f"WorkItems missing tenant_id/uid; sample={rows}")
    unresolved = list(session.run(
        "MATCH (w:WorkItem) WHERE w.summary IS NOT NULL "
        "AND (w.jira_id IS NULL OR w.jira_site_id IS NULL) "
        "RETURN w.uid AS uid, w.key AS key LIMIT 10"))
    if unresolved:
        raise RuntimeError(
            "Complete WorkItems still lack stable Jira identity; rebuild them from a full import "
            f"first: {unresolved}")
    duplicates = list(session.run(
        "MATCH (w:WorkItem) WHERE w.jira_id IS NOT NULL AND w.jira_site_id IS NOT NULL "
        "WITH w.tenant_id AS tenant, w.jira_site_id AS site, w.jira_id AS jira_id, count(*) AS n "
        "WHERE n > 1 RETURN tenant, site, jira_id, n LIMIT 10"))
    if duplicates:
        raise RuntimeError(f"Duplicate tenant/site/Jira issue identities; sample={duplicates}")


def main():
    driver = GraphDatabase.driver(
        os.getenv("NEO4J_URI"), auth=(os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASSWORD")))
    try:
        with driver.session() as session:
            validate_identity_data(session)
            for name in OLD_CONSTRAINTS:
                session.run(f"DROP CONSTRAINT {name} IF EXISTS")
                print(f"✓ dropped (if existed): {name}")
            # Older builds kept deletion tombstones; the decision is no trace after a delete.
            session.run("DROP CONSTRAINT deletiontombstone_uid_unique IF EXISTS")
            session.run("MATCH (d:DeletionTombstone) DETACH DELETE d")
            print("✓ removed legacy DeletionTombstone nodes and constraint (if any)")
            for label in UID_LABELS:
                q = (f"CREATE CONSTRAINT {label.lower()}_uid_unique IF NOT EXISTS "
                     f"FOR (n:{label}) REQUIRE n.uid IS UNIQUE")
                session.run(q)
                print(f"✓ {q}")
            session.run(WORKITEM_IDENTITY_CONSTRAINT)
            print(f"✓ {WORKITEM_IDENTITY_CONSTRAINT}")
            for q in INDEXES:
                session.run(q)
                print(f"✓ {q}")
        print("\nAll constraints and indexes are in place.")
    finally:
        driver.close()


if __name__ == "__main__":
    main()
