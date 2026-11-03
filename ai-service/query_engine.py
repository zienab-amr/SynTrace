"""
query_engine.py
GraphRAG retrieval layer (no LLM): بيجيب داتا من Neo4j بـ Cypher templates ثابتة.
"""
import os
import re
from neo4j import GraphDatabase
from dotenv import load_dotenv

load_dotenv()

URI = os.getenv("NEO4J_URI")
USER = os.getenv("NEO4J_USER")
PASSWORD = os.getenv("NEO4J_PASSWORD")

driver = GraphDatabase.driver(URI, auth=(USER, PASSWORD))

KEY_PATTERN = re.compile(r'\b([A-Za-z]+-\d+)\b')
MAX_KEYS = 5
MAX_RESULTS = 20


# ---------- Helpers ----------

def extract_keys(question):
    """كل الـ keys في السؤال، uppercase، من غير تكرار، بالترتيب."""
    found = [m.upper() for m in KEY_PATTERN.findall(question)]
    unique = list(dict.fromkeys(found))
    return unique[:MAX_KEYS]


def normalize_status(status):
    """بيوحّد كتابة الـ status (ToDo -> To Do)."""
    if not status:
        return "Unknown"
    s = status.strip()
    if s.replace(" ", "").lower() == "todo":
        return "To Do"
    return s


def run_query(query, **params):
    """المكان الوحيد اللي بيكلّم Neo4j (هنا هنحط tenant filter بعدين)."""
    with driver.session() as session:
        return list(session.run(query, **params))


def build_item(rkey, summary, status, url, assignee):
    """عنصر مرتبط. لو الـ node فاضي بيتعلّم incomplete بدل ما نخترع بيانات."""
    if summary is None:
        return {"key": rkey, "summary": None, "status": "Unknown",
                "assignee": "Unknown", "url": url, "incomplete": True}
    return {"key": rkey, "summary": summary,
            "status": normalize_status(status),
            "assignee": assignee or "Unassigned",
            "url": url, "incomplete": False}


def _items_from(records):
    return [
        build_item(r["rkey"], r["summary"], r["status"], r["url"], r["assignee"])
        for r in records if r["rkey"] is not None
    ]


# ---------- Retrieval functions ----------


def get_workitem_card(key):
    records = run_query(
        """
        MATCH (w:WorkItem {key: $key})
        WHERE coalesce(w.lifecycle_status, "active") = "active"
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(a:Person)
        OPTIONAL MATCH (w)-[:IN_SPRINT]->(s:Sprint)
        RETURN w.key AS key, w.summary AS summary, w.status AS status,
               w.statusCategory AS category, w.priority AS priority,
               w.project_key AS project, w.url AS url,
               a.displayName AS assignee,
               collect(DISTINCT s.name) AS sprints
        """,
        key=key,
    )
    if not records or records[0]["key"] is None:
        return None

    r = records[0]
    if r["summary"] is None:
        return {"key": key, "incomplete": True}

    return {
        "key": r["key"],
        "summary": r["summary"],
        "status": normalize_status(r["status"]),
        "status_category": r["category"],
        "priority": r["priority"] or "None",
        "project": r["project"],
        "assignee": r["assignee"] or "Unassigned",
        "sprints": r["sprints"] or [],
        "url": r["url"],
    }



def get_blockers(key):
    """Tickets that block this ticket: (b)-[:BLOCKS]->(w)."""
    records = run_query(
        f"""
        MATCH (w:WorkItem {{key: $key}})
        OPTIONAL MATCH (b:WorkItem)-[:BLOCKS]->(w)
        OPTIONAL MATCH (b)-[:ASSIGNED_TO]->(p:Person)
        RETURN b.key AS rkey, b.summary AS summary, b.status AS status,
               b.url AS url, p.displayName AS assignee
        ORDER BY b.key
        LIMIT {MAX_RESULTS}
        """,
        key=key,
    )
    if not records:
        return None
    return {"key": key, "items": _items_from(records)}


def get_blocked_by_me(key):
    """Tickets blocked by this ticket: (w)-[:BLOCKS]->(b)."""
    records = run_query(
        f"""
        MATCH (w:WorkItem {{key: $key}})
        OPTIONAL MATCH (w)-[:BLOCKS]->(b:WorkItem)
        OPTIONAL MATCH (b)-[:ASSIGNED_TO]->(p:Person)
        RETURN b.key AS rkey, b.summary AS summary, b.status AS status,
               b.url AS url, p.displayName AS assignee
        ORDER BY b.key
        LIMIT {MAX_RESULTS}
        """,
        key=key,
    )
    if not records:
        return None
    return {"key": key, "items": _items_from(records)}



def get_related(key):
    """التذاكر المرتبطة بـ RELATES_TO (الاتجاهين)."""
    records = run_query(
        f"""
        MATCH (w:WorkItem {{key: $key}})
        OPTIONAL MATCH (w)-[:RELATES_TO]-(r:WorkItem)
        OPTIONAL MATCH (r)-[:ASSIGNED_TO]->(p:Person)
        RETURN r.key AS rkey, r.summary AS summary, r.status AS status,
               r.url AS url, p.displayName AS assignee
        ORDER BY r.key
        LIMIT {MAX_RESULTS}
        """,
        key=key,
    )
    if not records:
        return None
    return {"key": key, "items": _items_from(records)}


# ---------- Entry point ----------

def answer_key_question(question):
    """
    بترجّع list من النتايج، واحدة لكل key في السؤال.
    types: found | incomplete | not_found | no_key_found
    """
    keys = extract_keys(question)

    if not keys:
        return [{"type": "no_key_found",
                 "message": "No ticket key found in the question."}]

    results = []
    for key in keys:
        card = get_workitem_card(key)
        if card is None:
            results.append({"type": "not_found", "key": key,
                            "message": f"No ticket found with key {key}."})
        elif card.get("incomplete"):
            results.append({"type": "incomplete", "key": key,
                            "message": f"Ticket {key} is referenced but its data is incomplete."})
        else:
            results.append({"type": "found", "card": card})
    return results


if __name__ == "__main__":
    for q in ["What is the status of SYNTECH-5?", "who is on syntech-5?",
              "Compare SYNTECH-5 and SYNDATA-12", "What about SYNTECH-9999?",
              "How is the weather today?"]:
        print(f"\nQ: {q}")
        for res in answer_key_question(q):
            print("  ->", res)

    print("\n--- Blockers ---")
    for k in ["SYNDATA-3", "SYNTECH-9999"]:
        print(k, "->", get_blockers(k))

    print("\n--- Blocks ---")
    for k in ["SYNTECH-11", "SYNTECH-9999"]:
        print(k, "->", get_blocked_by_me(k))