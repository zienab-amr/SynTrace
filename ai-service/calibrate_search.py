"""Print the best semantic matches and their scores, to choose SEMANTIC_MIN_SCORE on real data.

  python calibrate_search.py
"""
import sys

from query_engine import default_context
from semantic_search import semantic_search

QUESTIONS = [
    ("related", "tickets about login"),
    ("related", "فيه تذاكر عن تسجيل الدخول؟"),
    ("related", "knowledge graph"),
    ("related", "التذاكر الخاصة بالـ graph"),
    ("related", "database"),
    ("related", "Flutter screens"),
    ("related", "شاشات الموبايل"),
    ("related", "meeting transcripts"),
    ("related", "webhook events"),
    ("unrelated", "How is the weather today?"),
    ("unrelated", "الجو عامل ايه النهاردة؟"),
    ("unrelated", "best pizza recipe"),
    ("unrelated", "من فاز بكأس العالم؟"),
]


def main():
    sys.stdout.reconfigure(errors="backslashreplace", line_buffering=True)
    ctx = default_context()
    for kind, question in QUESTIONS:
        print(f"\n[{kind}] {question}")
        for hit in semantic_search(question, ctx, k=5, min_score=0.0):
            print(f"  {hit['score']:.3f}  {hit['key']:<12} {hit['summary']}")


if __name__ == "__main__":
    main()
