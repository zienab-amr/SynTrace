"""Ask a fixed list of real-language questions and save the answers for manual review."""
import csv
import glob
import json
import re
import sys
import time
from collections import Counter

from answer_generator import generate_answer_result
from query_engine import default_context

QUESTIONS = [
    ("arabic_key", "ايه حالة SYNDATA-26؟"),
    ("arabic_key", "مين ماسك SYNTECH-47؟"),
    ("arabic_key", "مين شغال على التذكرة SYNDATA-101؟"),
    ("arabic_key", "ايه اللي موقف SYNDATA-22؟"),
    ("arabic_key", "SYNTECH-19 معطلة ايه؟"),
    ("arabic_key", "ايه التذاكر المرتبطة بـ SYNDATA-91؟"),
    ("arabic_key", "SYNTECH-44 هتخلص امتى؟"),
    ("arabic_key", "قارن بين SYNTECH-56 و SYNDATA-70"),
    ("arabic_key", "لخصلي SYNDATA-29"),
    ("arabic_key", "مين علق على SYNDATA-14 وقال ايه؟"),
    ("mixed", "SYNDATA-26 status ايه؟"),
    ("mixed", "مين الـ assignee بتاع SYNTECH-47؟"),
    ("lowercase_key", "ايه حالة syndata-26؟"),
    ("history", "مين غيّر حالة SYNDATA-2 وامتى؟"),
    ("people", "مين عمل SYNDATA-2؟"),
    ("children", "ايه الـ subtasks بتاعة SYNDATA-14؟"),
    ("aggregate", "كام epic عندنا؟"),
    ("aggregate", "ايه التذاكر تحت Identity and Knowledge Graph؟"),
    ("aggregate", "مين سجل أكتر وقت؟"),
    ("aggregate", "ايه آخر الكومنتات؟"),
    ("aggregate", "ايه آخر تغييرات الحالة؟"),
    ("person", "تذاكر فاطمة"),
    ("person", "كام تذكرة عند زينب؟"),
    ("person", "How many tickets does Martina have?"),
    ("person", "تذاكر أحمد"),
    ("me", "ايه تذاكري؟"),
    ("transition", "مين قفل أكتر تذاكر؟"),
    ("transition", "ايه التذاكر اللي رجعت Reopened؟"),
    ("transition", "Which tickets moved from In Review back to In Progress?"),
    ("comments", "مين اللي رفض تذكرة في QA وليه؟"),
    ("comments", "فين اتكلموا عن OAuth state في الكومنتات؟"),
    ("comments", "Which comments mention blockers?"),
    ("no_key_detail", "هل تذكرة فلترة الـ retrieval بتعطل حاجة؟"),
    ("children", "What is blocking SYNDATA-14's subtasks, if anything?"),
    ("aggregate", "Which epic has the most child tickets?"),
    ("custom_field", "كام story point في SYNDATA-113؟"),
    ("no_key_detail", "مين ماسك تذكرة شاشات تسجيل الدخول في Flutter؟"),
    ("no_key_detail", "ايه حالة تذكرة رفع الـ meeting transcripts؟"),
    ("no_key_detail", "مين شغال على موضوع الـ dead letter queue؟"),
    ("no_key_detail", "Who is working on the knowledge graph model?"),
    ("keyword", "tickets about OAuth"),
    ("keyword", "فين الكلام عن SignalR؟"),
    ("semantic", "فيه تذاكر عن تسجيل الدخول؟"),
    ("semantic", "Which tickets are about the database?"),
    ("semantic", "شاشات الموبايل"),
    ("semantic", "التذاكر الخاصة بالـ graph"),
    ("semantic", "meeting transcripts"),
    ("semantic", "best pizza recipe"),
    ("aggregate", "مين عنده أكتر تذاكر؟"),
    ("aggregate", "كام تذكرة مفتوحة في SYNDATA؟"),
    ("aggregate", "How many tickets are done in SYNTECH?"),
    ("aggregate", "ايه التذاكر اللي معاد تسليمها فات؟"),
    ("sprint", "ايه التذاكر اللي في السبرنت الحالي؟"),
    ("sprint", "Which sprint is SYNDATA-26 in?"),
    ("out_of_scope", "الجو عامل ايه النهاردة؟"),
    ("not_found", "ايه حالة SYNDATA-9000؟"),
]


def expected_numbers():
    """Exact numbers from the ticket files, to compare with the aggregate answers."""
    tickets = []
    for path in glob.glob("all_tickets/*.json"):
        with open(path, encoding="utf-8") as handle:
            tickets.append(json.load(handle))
    project = lambda t: t["key"].split("-")[0]
    category = lambda t: t["fields"]["status"]["statusCategory"]["key"]
    people = Counter((t["fields"].get("assignee") or {}).get("displayName") for t in tickets)
    if not tickets:
        print("all_tickets is missing: the number checks are skipped.")
        return {}
    return {
        "مين عنده أكتر تذاكر؟": str(people.most_common(1)[0][1]) if people else "",
        "كام تذكرة مفتوحة في SYNDATA؟": str(sum(project(t) == "SYNDATA" and category(t) != "done" for t in tickets)),
        "How many tickets are done in SYNTECH?": str(sum(project(t) == "SYNTECH" and category(t) == "done" for t in tickets)),
    }


def main():
    sys.stdout.reconfigure(errors="backslashreplace")
    ctx = default_context()
    expected = expected_numbers()
    with open("ask_batch_results.csv", "w", newline="", encoding="utf-8-sig") as out:
        writer = csv.writer(out)
        writer.writerow(["category", "question", "status", "number_check", "answer"])
        for number, (category, question) in enumerate(QUESTIONS, 1):
            try:
                result = generate_answer_result(question, ctx)
                status, answer = result["status"], result["answer"]
            except Exception as error:
                status, answer = "error", repr(error)
            check = ""
            if question in expected:
                check = "PASS" if re.search(rf"\b{expected[question]}\b", answer) else f"FAIL (expected {expected[question]})"
            writer.writerow([category, question, status, check, answer])
            print(f"[{number}/{len(QUESTIONS)}] {status} {check}: {question}")
            time.sleep(6)   # stay under the Groq rate limit
    print("Saved: ask_batch_results.csv")


if __name__ == "__main__":
    main()