"""
evaluate_graphrag.py
تقييم الـ GraphRAG بأسئلة مولّدة من ملفات الـ JSON (المصدر الحقيقي)، مش من الـ graph.
مش بيعدّل أي حاجة في Neo4j.

وضعين:
  python evaluate_graphrag.py                 # retrieval بس (من غير LLM): كل التذاكر، سريع ومضمون
  python evaluate_graphrag.py --llm           # end-to-end (Groq): أسئلة بصياغات مختلفة
  python evaluate_graphrag.py --llm --n 10 --seed 1 --sleep 1.5

النتيجة: ملخص بالنسب لكل فئة، وأمثلة الأخطاء، وملف eval_results.csv بكل الحالات.
"""
import argparse
import contextlib
import csv
import glob
import io
import json
import logging
import os
import random
import re
import sys
import time
from collections import defaultdict

KEY_RE = re.compile(r"\b[A-Z]+-\d+\b")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")


def squish(s):
    return re.sub(r"[\s\-_]", "", (s or "").lower())


# ------------------------------------------------------------------
# 1) الحقيقة (Ground truth) من الملفات
# ------------------------------------------------------------------
def load_truth(folder):
    tickets, blocks, relates = {}, set(), set()
    for path in glob.glob(os.path.join(folder, "*.json")):
        with open(path, encoding="utf-8") as f:
            issue = json.load(f)
        fl, key = issue["fields"], issue["key"]
        tickets[key] = {
            "status": fl["status"]["name"],
            "assignee": (fl.get("assignee") or {}).get("displayName"),
            "duedate": fl.get("duedate"),
        }
        for link in fl.get("issuelinks", []):
            if "outwardIssue" in link:
                a, b = key, link["outwardIssue"]["key"]
            elif "inwardIssue" in link:
                a, b = link["inwardIssue"]["key"], key
            else:
                continue
            if link["type"]["name"] == "Blocks":
                blocks.add((a, b))
            elif link["type"]["name"] == "Relates":
                relates.add(frozenset((a, b)))
    blockers = defaultdict(set)   # ticket -> اللي بيعطّلوه
    blocked = defaultdict(set)    # ticket -> اللي بيعطّلهم
    for a, b in blocks:
        blockers[b].add(a)
        blocked[a].add(b)
    related = defaultdict(set)
    for p in relates:
        x, y = tuple(p)
        related[x].add(y)
        related[y].add(x)
    for k in tickets:
        blockers.setdefault(k, set()); blocked.setdefault(k, set()); related.setdefault(k, set())
    children = defaultdict(set)   # ticket -> اللي CHILD_OF ليها (parent field + subtasks)
    for path in glob.glob(os.path.join(folder, "*.json")):
        with open(path, encoding="utf-8") as f:
            issue = json.load(f)
        fl, key = issue["fields"], issue["key"]
        if fl.get("parent"):
            children[fl["parent"]["key"]].add(key)
        for sub in fl.get("subtasks") or []:
            children[key].add(sub["key"])
    return tickets, blockers, blocked, related, children


# ------------------------------------------------------------------
# 2) توليد الأسئلة
# ------------------------------------------------------------------
TEMPLATES = {
    "status":   ["What is the status of {k}?", "What's the current status of {k}?",
                 "{k} status?", "ايه حالة {k}؟"],
    "assignee": ["Who is assigned to {k}?", "Who is working on {k}?", "Who owns {k}?"],
    "blockers": ["What blocks {k}?", "Who blocks {k}?", "List the blockers of {k}",
                 "Which tickets are blocking {k}?", "What is {k} blocked by?"],
    "blocks":   ["What tickets does {k} block?", "Is {k} blocking anything?",
                 "Which tickets are blocked by {k}?", "What does {k} block?"],
    "related":  ["What is related to {k}?", "Which tickets are related to {k}?",
                 "Show tickets connected to {k}"],
    "duedate":  ["What is the due date of {k}?", "When is {k} due?"],
}


def pick(keys_pos, keys_neg, n, rng):
    """أغلبها حالات فيها نتايج، وحصة للحالات الفاضية (لازم النظام ما يألفش)."""
    rng.shuffle(keys_pos); rng.shuffle(keys_neg)
    n_neg = min(len(keys_neg), max(1, n * 3 // 10))
    out = keys_pos[: n - n_neg] + keys_neg[:n_neg]
    rng.shuffle(out)
    return out


def build_cases(truth, n, rng):
    tickets, blockers, blocked, related, children = truth
    keys = sorted(tickets)
    projects = sorted({k.rsplit("-", 1)[0] for k in tickets})
    cases = []

    def add(cat, tid, q, **exp):
        cases.append({"cat": cat, "tid": tid, "q": q, **exp})

    for cat, key_fn in (("status", None), ("assignee", None)):
        sample = rng.sample(keys, min(n, len(keys)))
        for i, k in enumerate(sample):
            if cat == "status":
                add(cat, i % len(TEMPLATES[cat]), TEMPLATES[cat][i % len(TEMPLATES[cat])].format(k=k),
                    key=k, expect=tickets[k]["status"])
            elif tickets[k]["assignee"]:
                add(cat, i % len(TEMPLATES[cat]), TEMPLATES[cat][i % len(TEMPLATES[cat])].format(k=k),
                    key=k, expect=tickets[k]["assignee"])

    for cat, mapping in (("blockers", blockers), ("blocks", blocked), ("related", related)):
        pos = [k for k in keys if mapping[k]]
        neg = [k for k in keys if not mapping[k]]
        for i, k in enumerate(pick(pos, neg, n, rng)):
            t = TEMPLATES[cat]
            exp = {"key": k, "expect": set(mapping[k])}
            if "connected" in t[i % len(t)]:
                # "Connected" is broader than the Relates link: any real link or hierarchy is correct.
                exp["allowed"] = (set(related[k]) | set(blockers[k]) | set(blocked[k]) | set(children.get(k, ()))
                                  | {p for p, kids in children.items() if k in kids})
            add(cat, i % len(t), t[i % len(t)].format(k=k), **exp)

    no_due = [k for k in keys if not tickets[k]["duedate"]]
    for i, k in enumerate(rng.sample(no_due, min(max(3, n // 3), len(no_due)))):
        t = TEMPLATES["duedate"]
        add("duedate", i % len(t), t[i % len(t)].format(k=k), key=k)

    for i, k in enumerate(rng.sample(keys, min(max(3, n // 3), len(keys)))):
        k2 = rng.choice([x for x in keys if x != k])
        add("compare", 0, f"Compare {k} and {k2}", keys=(k, k2),
            expect={k: tickets[k], k2: tickets[k2]})

    for i in range(max(2, n // 5)):
        proj = rng.choice(projects)
        add("not_found", 0, f"What about {proj}-{9000 + i}?", key=f"{proj}-{9000 + i}")
    add("no_key", 0, "How is the weather today?")
    add("no_key", 1, "Which tickets are about login?")
    return cases


# ------------------------------------------------------------------
# 3) التصحيح: إجابة نصية (end-to-end)
# ------------------------------------------------------------------
def other_keys(answer, asked):
    return {k for k in KEY_RE.findall(answer.upper())} - {asked}


def grade_text(case, answer):
    cat, low = case["cat"], answer.lower()
    if cat == "status":
        ok = squish(case["expect"]) in squish(answer)
        return ok, "" if ok else f"المتوقع status={case['expect']}"
    if cat == "assignee":
        ok = case["expect"].lower() in low
        return ok, "" if ok else f"المتوقع assignee={case['expect']}"
    if cat in ("blockers", "blocks", "related"):
        got, exp = other_keys(answer, case["key"]), case["expect"]
        if got == exp or ("allowed" in case and exp <= got <= case["allowed"]):
            return True, ""
        return False, f"ناقص={sorted(exp - got)} زيادة={sorted(got - exp)}"
    if cat == "duedate":
        ok = not DATE_RE.search(answer)
        return ok, "" if ok else "ألّف تاريخ"
    if cat == "compare":
        bad = [k for k, t in case["expect"].items()
               if not (squish(t["status"]) in squish(answer)
                       or (t["assignee"] and t["assignee"].lower() in low))]
        return (not bad), "" if not bad else f"مفيش status/assignee لـ {bad}"
    if cat == "not_found":
        ok = "no ticket found" in low
        return ok, "" if ok else "المفروض يقول no ticket found"
    if cat == "no_key":
        if case["tid"] == 0:   # سؤال مالوش علاقة: المفروض ما يرجّعش تذاكر
            ok = "jira ticket key" in low and not KEY_RE.search(
                answer.upper().replace("PROJ-123", ""))
            return ok, "" if ok else "سؤال مالوش علاقة: المفروض يطلب ticket key"
        ok = ("jira ticket key" in low) or bool(KEY_RE.search(answer.upper()))
        return ok, "" if ok else "المفروض يرجّع تذاكر (semantic) أو يطلب ticket key"
    return False, "فئة غير معروفة"


# ------------------------------------------------------------------
# 4) التصحيح: retrieval بس (من غير LLM)
# ------------------------------------------------------------------
def require_visible_tickets(qe, ctx):
    in_scope = qe.run_query("MATCH (w:WorkItem {tenant_id: $tenant}) WHERE w.project_key IN $allowed "
                            "AND w.summary IS NOT NULL RETURN count(w) AS n", **qe._scope(ctx))[0]["n"]
    if not in_scope:
        sys.exit(f"No tickets visible for tenant={ctx.tenant_id} projects={ctx.allowed_projects}. "
                 "This is a setup problem, not a score: run python check_graph.py")


class LlmFailureCounter(logging.Handler):
    def __init__(self):
        super().__init__(logging.WARNING)
        self.count = 0

    def emit(self, record):
        if "LLM call failed" in record.getMessage():
            self.count += 1


def run_retrieval(truth):
    import query_engine as qe
    ctx = qe.default_context()
    require_visible_tickets(qe, ctx)
    tickets, blockers, blocked, related, children = truth
    cases = []

    def keys_of(r):
        return {i["key"] for i in r["items"]} if r else None

    for k in sorted(tickets):
        t = tickets[k]
        card = qe.get_workitem_card(k, ctx)
        ok = bool(card) and squish(card.get("status")) == squish(t["status"])
        cases.append({"cat": "status", "tid": 0, "q": f"[retrieval] status {k}", "ok": ok,
                      "why": "" if ok else f"graph={card and card.get('status')} ملف={t['status']}"})
        if t["assignee"]:
            ok = bool(card) and card.get("assignee") == t["assignee"]
            cases.append({"cat": "assignee", "tid": 0, "q": f"[retrieval] assignee {k}", "ok": ok,
                          "why": "" if ok else f"graph={card and card.get('assignee')} ملف={t['assignee']}"})
        for cat, fn, mapping in (("blockers", qe.get_blockers, blockers),
                                 ("blocks", qe.get_blocked_by_me, blocked),
                                 ("related", qe.get_related, related)):
            got = keys_of(fn(k, ctx))
            ok = got == mapping[k]
            cases.append({"cat": cat, "tid": 0, "q": f"[retrieval] {cat} {k}", "ok": ok,
                          "why": "" if ok else f"graph={sorted(got or [])} ملف={sorted(mapping[k])}"})
    for k in sorted(tickets):   # subtasks / children: العدد لازم يطابق الملفات
        exp = children.get(k, set())
        got = qe.get_children(k, ctx, limit=0)
        ok = bool(got) and got["total"] == len(exp)
        cases.append({"cat": "children", "tid": 0, "q": f"[retrieval] children {k}", "ok": ok,
                      "why": "" if ok else f"graph={got and got['total']} ملف={len(exp)}"})
    for fake in [f"{p}-9001" for p in sorted({k.rsplit('-', 1)[0] for k in tickets})]:
        res = qe.answer_key_question(f"What about {fake}?", ctx)[0]
        ok = res["type"] == "not_found"
        cases.append({"cat": "not_found", "tid": 0, "q": f"[retrieval] {fake}", "ok": ok,
                      "why": "" if ok else str(res)})
    res = qe.answer_key_question("How is the weather today?", ctx)[0]
    ok = res["type"] == "no_key_found"
    cases.append({"cat": "no_key", "tid": 0, "q": "[retrieval] no key", "ok": ok,
                  "why": "" if ok else str(res)})
    return cases


def run_llm(cases, sleep):
    from answer_generator import generate_answer
    import query_engine as qe
    ctx = qe.default_context()
    require_visible_tickets(qe, ctx)
    failures = LlmFailureCounter()
    answer_log = logging.getLogger("syntrace.answer")
    answer_log.addHandler(failures)
    answer_log.propagate = False
    out = []
    for i, c in enumerate(cases, 1):
        before = failures.count
        with contextlib.redirect_stdout(io.StringIO()):
            ans = generate_answer(c["q"], ctx)
        ok, why = grade_text(c, ans)
        llm_failed = failures.count > before
        out.append({"cat": c["cat"], "tid": c["tid"], "q": c["q"], "ok": ok, "why": why,
                    "answer": ans.split("\n\n")[0][:300].replace("\n", " | "),
                    "llm_failed": llm_failed})
        print(f"  [{i}/{len(cases)}] {'✓' if ok else '✗'} {c['q']}")
        time.sleep(sleep)
    return out


# ------------------------------------------------------------------
# 5) التقرير
# ------------------------------------------------------------------
def report(results, out_csv):
    by_cat = defaultdict(list)
    for r in results:
        by_cat[r["cat"]].append(r)
    print("\n================ النتيجة حسب الفئة ================")
    total_ok = 0
    for cat, rs in by_cat.items():
        ok = sum(r["ok"] for r in rs)
        total_ok += ok
        print(f"{cat:<10} {ok:>4}/{len(rs):<4} {100 * ok / len(rs):5.1f}%")
    print(f"{'الإجمالي':<10} {total_ok:>4}/{len(results):<4} {100 * total_ok / len(results):5.1f}%")

    if any("answer" in r for r in results):
        print("\n================ النتيجة حسب صياغة السؤال ================")
        by_t = defaultdict(list)
        for r in results:
            if r["cat"] in TEMPLATES:
                by_t[(r["cat"], r["tid"])].append(r["ok"])
        for (cat, tid), oks in sorted(by_t.items()):
            tmpl = TEMPLATES[cat][tid]
            print(f"{cat:<9} {sum(oks)}/{len(oks)}  \"{tmpl}\"")
        fails = sum(r.get("llm_failed", False) for r in results)
        print(f"\nمرات فشل الـ LLM ورجع للـ template: {fails}")

    bad = [r for r in results if not r["ok"]]
    if bad:
        print(f"\n================ الأخطاء ({len(bad)}) — أول 15 ================")
        for r in bad[:15]:
            print(f"- [{r['cat']}] {r['q']}\n    {r['why']}")
            if r.get("answer"):
                print(f"    الإجابة: {r['answer']}")
    with open(out_csv, "w", newline="", encoding="utf-8-sig") as f:
        cols = ["cat", "tid", "q", "ok", "why", "answer", "llm_failed"]
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(results)
    print(f"\nاتحفظت كل الحالات في: {out_csv}")
    return len(bad)


if __name__ == "__main__":
    sys.stdout.reconfigure(errors="backslashreplace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="all_tickets")
    ap.add_argument("--llm", action="store_true", help="تقييم end-to-end بالـ LLM")
    ap.add_argument("--n", type=int, default=10, help="عدد الأسئلة لكل فئة (وضع --llm)")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--sleep", type=float, default=1.0, help="ثواني بين طلبات Groq")
    ap.add_argument("--out", default="eval_results.csv")
    args = ap.parse_args()

    sys.path.insert(0, os.getcwd())
    truth = load_truth(args.dir)
    if not truth[0]:
        sys.exit(f"No ticket files in {args.dir}/. Copy all_tickets and field_meta.json next to this script.")
    print(f"الحقيقة من الملفات: {len(truth[0])} تذكرة")

    if args.llm:
        cases = build_cases(truth, args.n, random.Random(args.seed))
        print(f"وضع end-to-end: {len(cases)} سؤال (seed={args.seed})\n")
        results = run_llm(cases, args.sleep)
    else:
        print("وضع retrieval (من غير LLM): كل التذاكر\n")
        results = run_retrieval(truth)
    raise SystemExit(1 if report(results, args.out) else 0)