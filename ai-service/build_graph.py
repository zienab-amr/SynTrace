"""
build_graph.py
يحول raw Jira JSON لـ nodes/edges في Neo4j.
المرحلة 2: + Project, Sprint, issuelinks
"""
import json
import os
from neo4j import GraphDatabase
from dotenv import load_dotenv
import glob
from adf_parser import parse_adf_description
import re

load_dotenv()

URI = os.getenv("NEO4J_URI")
USER = os.getenv("NEO4J_USER")
PASSWORD = os.getenv("NEO4J_PASSWORD")

driver = GraphDatabase.driver(URI, auth=(USER, PASSWORD))


def load_issue(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


def build_workitem_core(tx, issue):
    """WorkItem node + description parsing (زي المرحلة 1)"""
    fields = issue["fields"]
    key = issue["key"]

    parsed_desc = parse_adf_description(fields.get("description"))

    workitem_props = {
        "key": key,
        "summary": fields.get("summary"),
        "issuetype": fields["issuetype"]["name"],
        "hierarchyLevel": fields["issuetype"]["hierarchyLevel"],
        "status": fields["status"]["name"],
        "statusCategory": fields["status"]["statusCategory"]["key"],
        "priority": fields["priority"]["name"] if fields.get("priority") else None,
        "created": fields.get("created"),
        "updated": fields.get("updated"),
        "resolutiondate": fields.get("resolutiondate"),
        "duedate": fields.get("duedate"),
        "labels": fields.get("labels", []),
        "project_key": fields["project"]["key"],
        "description_intro": parsed_desc["intro"],
        "description_sections": json.dumps(parsed_desc["sections"], ensure_ascii=False),
        "url": f"https://syntrace.atlassian.net/browse/{key}",
    }

    tx.run(
        """
        MERGE (w:WorkItem {key: $key})
        SET w += $props
        """,
        key=key,
        props=workitem_props,
    )


def build_people(tx, issue):
    """Assignee + Reporter edges (من غير إيميل)"""
    fields = issue["fields"]
    key = issue["key"]

    assignee = fields.get("assignee")
    if assignee:
        tx.run(
            """
            MERGE (p:Person {accountId: $accountId})
            SET p.displayName = coalesce($displayName, p.displayName)
            WITH p
            MATCH (w:WorkItem {key: $key})
            MERGE (w)-[:ASSIGNED_TO]->(p)
            """,
            accountId=assignee["accountId"],
            displayName=assignee.get("displayName"),
            key=key,
        )

    reporter = fields.get("reporter")
    if reporter:
        tx.run(
            """
            MERGE (p:Person {accountId: $accountId})
            SET p.displayName = coalesce($displayName, p.displayName)
            WITH p
            MATCH (w:WorkItem {key: $key})
            MERGE (w)-[:REPORTED_BY]->(p)
            """,
            accountId=reporter["accountId"],
            displayName=reporter.get("displayName"),
            key=key,
        )


def build_project(tx, issue):
    """Project node + BELONGS_TO edge"""
    fields = issue["fields"]
    key = issue["key"]
    project = fields.get("project")

    if project:
        tx.run(
            """
            MERGE (pr:Project {key: $project_key})
            SET pr.name = $project_name, pr.projectTypeKey = $project_type
            WITH pr
            MATCH (w:WorkItem {key: $key})
            MERGE (w)-[:BELONGS_TO]->(pr)
            """,
            project_key=project["key"],
            project_name=project.get("name"),
            project_type=project.get("projectTypeKey"),
            key=key,
        )


def build_sprint(tx, issue):
    """
    Sprint node + IN_SPRINT edge.
    customfield_10020 ده الحقل بتاع الـ Sprint في المشروع ده تحديدًا
    (فاكرة: الرقم ده مش مضمون يفضل نفسه في مشاريع تانية،
    بس دلوقتي بنشتغل على SYNTECH بس فهو ثابت هنا).
    """
    fields = issue["fields"]
    key = issue["key"]
    sprints = fields.get("customfield_10020")

    if not sprints:
        return

    for sprint in sprints:
        tx.run(
            """
            MERGE (s:Sprint {id: $sprint_id})
            SET s.name = $name, s.state = $state, s.goal = $goal,
                s.startDate = $startDate, s.endDate = $endDate
            WITH s
            MATCH (w:WorkItem {key: $key})
            MERGE (w)-[:IN_SPRINT]->(s)
            """,
            sprint_id=sprint["id"],
            name=sprint.get("name"),
            state=sprint.get("state"),
            goal=sprint.get("goal"),
            startDate=sprint.get("startDate"),
            endDate=sprint.get("endDate"),
            key=key,
        )


def build_issuelinks(tx, issue):
    """
    الاتجاه: بنستخدم دايمًا اسم الـ outward ("blocks", "relates to").
    - outwardIssue: (current)-[REL]->(other)
    - inwardIssue : (other)-[REL]->(current)

    """
    key = issue["key"]
    for link in issue["fields"].get("issuelinks", []):
        rel_type = re.sub(r"[^A-Z0-9_]", "_", link["type"]["outward"].upper().replace(" ", "_"))

        if "outwardIssue" in link:
            src, dst = key, link["outwardIssue"]["key"]
        elif "inwardIssue" in link:
            src, dst = link["inwardIssue"]["key"], key
        else:
            continue

        tx.run(
            f"""
            MERGE (a:WorkItem {{key: $src}})
            MERGE (b:WorkItem {{key: $dst}})
            MERGE (a)-[:{rel_type}]->(b)
            """,
            src=src,
            dst=dst,
        )


def build_everything(tx, issue):
    build_workitem_core(tx, issue)
    build_people(tx, issue)
    build_project(tx, issue)
    build_sprint(tx, issue)
    build_issuelinks(tx, issue)


def process_file(filepath):
    issue = load_issue(filepath)
    with driver.session() as session:
        session.execute_write(build_everything, issue)
    print(f"✓ Processed {issue['key']} from {filepath}")



if __name__ == "__main__":
    files = glob.glob("all_tickets/*.json")
    print(f">>> Found {len(files)} files to process\n")
    for f in files:
        print(f"\n=== Processing {f} ===")
        process_file(f)
    print("\n>>> All done")