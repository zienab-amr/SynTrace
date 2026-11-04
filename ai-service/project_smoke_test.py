"""Compare assistant counts with direct graph counts for every project in scope.

  python project_smoke_test.py

Run it where all company projects are imported. It uses a few Groq tokens per project.
"""
import sys

from answer_generator import generate_answer_result
from query_engine import default_context, run_query


def graph_counts(ctx):
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $tenant}) WHERE w.project_key IN $allowed AND w.summary IS NOT NULL "
        "RETURN w.project_key AS project, count(w) AS total, "
        "sum(CASE WHEN w.statusCategory = 'done' THEN 1 ELSE 0 END) AS done ORDER BY project",
        tenant=ctx.tenant_id, allowed=list(ctx.allowed_projects))
    return [dict(row) for row in rows]


def contains_number(answer, number):
    return str(number) in answer.replace(",", "")


def main():
    sys.stdout.reconfigure(errors="backslashreplace", line_buffering=True)
    ctx = default_context()
    failures = 0
    for row in graph_counts(ctx):
        project = row["project"]
        checks = ((f"كام تذكرة في {project}؟", row["total"]),
                  (f"How many tickets are done in {project}?", row["done"]))
        for question, expected in checks:
            answer = generate_answer_result(question, ctx)["answer"]
            ok = contains_number(answer, expected)
            failures += not ok
            print(f"{'PASS' if ok else 'FAIL'} {question} expected={expected}")
            if not ok:
                print(f"     {answer[:200]}")
    print(f"Failures: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())