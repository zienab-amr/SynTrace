from neo4j import GraphDatabase
from dotenv import load_dotenv
import os

load_dotenv()

URI = os.getenv("NEO4J_URI")
USER = os.getenv("NEO4J_USER")
PASSWORD = os.getenv("NEO4J_PASSWORD")

driver = GraphDatabase.driver(URI, auth=(USER, PASSWORD))

CONSTRAINTS = [
    "CREATE CONSTRAINT workitem_key_unique IF NOT EXISTS FOR (w:WorkItem) REQUIRE w.key IS UNIQUE",
    "CREATE CONSTRAINT person_account_unique IF NOT EXISTS FOR (p:Person) REQUIRE p.accountId IS UNIQUE",
    "CREATE CONSTRAINT project_key_unique IF NOT EXISTS FOR (pr:Project) REQUIRE pr.key IS UNIQUE",
    "CREATE CONSTRAINT sprint_id_unique IF NOT EXISTS FOR (s:Sprint) REQUIRE s.id IS UNIQUE",
]

def setup_constraints():
    with driver.session() as session:
        for constraint in CONSTRAINTS:
            session.run(constraint)
            print(f"✓ {constraint}")

try:
    setup_constraints()
    print("\nAll constraints created successfully.")
except Exception as e:
    print(f"Error: {e}")
finally:
    driver.close()