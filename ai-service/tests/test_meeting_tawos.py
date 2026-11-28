"""Meeting notes on real TAWOS tickets in the lab Neo4j (tenant "lab"), with the real Groq model and Ollama.

  run by run_meeting_test.ps1 with TAWOS_TEST=1

A transcript is built from real tickets: one is named by key, one is only described, and one key does
not exist. The test checks the extraction, linking, suggestions, review and the assistant's answer,
prints what it saw, and deletes the meeting source at the end. The TAWOS tickets are never changed.
"""
import json
import os
import time
import unittest
import unittest.mock

from dotenv import load_dotenv

load_dotenv()

from syntrace_ai.meetings import meeting_notes as mn
from syntrace_ai.graph.query_engine import AccessContext, run_query

READY = os.getenv("NEO4J_INTEGRATION") == "1" and os.getenv("TAWOS_TEST") == "1"
TENANT = "lab"
SOURCE_ID = "tawos-meeting-test"


def pick_tickets():
    """The project with the most embedded tickets, and three of its tickets with clear summaries."""
    project = run_query(
        "MATCH (w:WorkItem {tenant_id: $t}) WHERE w.embedding IS NOT NULL AND w.summary IS NOT NULL "
        "RETURN w.project_key AS p, count(*) AS n ORDER BY n DESC LIMIT 1", t=TENANT)[0]["p"]
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $t, project_key: $p}) WHERE w.embedding IS NOT NULL "
        "AND size(w.summary) >= 25 AND size(w.summary) <= 90 AND NOT w.summary CONTAINS '-' "
        "RETURN w.key AS key, w.summary AS summary ORDER BY w.key DESC LIMIT 3", t=TENANT, p=project)
    return project, rows


@unittest.skipUnless(READY, "requires NEO4J_INTEGRATION=1, TAWOS_TEST=1 and the lab Neo4j")
class TawosMeetingTests(unittest.TestCase):
    def setUp(self):
        self.project, self.tickets = pick_tickets()
        self.assertEqual(len(self.tickets), 3, "the lab graph needs embedded tickets")
        self.ctx = AccessContext(TENANT, (self.project,))
        self.cleanup()

    def tearDown(self):
        self.cleanup()

    def cleanup(self):
        uid = mn.source_uid(TENANT, SOURCE_ID)
        run_query("MATCH (s:Source {uid: $uid}) OPTIONAL MATCH (s)-[:HAS_ITEM|HAS_CHUNK]->(n) DETACH DELETE n, s",
                  uid=uid)

    def test_meeting_on_real_tickets(self):
        described, named, _ = self.tickets
        missing = f"{self.project}-999999"
        transcript = (
            f"Client: We still need this fixed before the release: {described['summary']}. It is our top priority.\n"
            f"Developer: {named['key']} is blocked because the staging server is down since Monday.\n"
            f"Developer: {missing} also depends on the staging server.\n"
            "Product owner: Maybe we could move the release one week, but nothing is decided yet.\n"
            "Developer: Call me on 0100 243 1647 if staging comes back.\n"
            "Client: We agreed that the release notes will be written in English only.\n")
        print(f"\nproject {self.project}\ndescribed: {described['key']} {described['summary']}\n"
              f"named: {named['key']} {named['summary']}\n")

        result = mn.submit_source(self.ctx, SOURCE_ID, self.project, "online", "TAWOS release sync",
                                  "2026-11-05", text=transcript, inline=True)
        source, items = result["source"], result["items"]
        print("status:", source["status"], source.get("error"))
        print("unresolved:", source["unresolved_keys"], "rejected:", source["rejected_items"])
        print(json.dumps(items, ensure_ascii=False, indent=1))
        self.assertEqual(source["status"], mn.PENDING, source.get("error"))
        self.assertTrue(items)

        stored = run_query("MATCH (s:Source {uid: $uid}) RETURN s.text AS text",
                           uid=mn.source_uid(TENANT, SOURCE_ID))[0]["text"]
        self.assertNotIn("1647", stored)
        self.assertTrue(all("1647" not in i["evidence"] for i in items))
        self.assertTrue(all(mn.MASK not in i["text"] for i in items), "contact details became an item")

        linked = {link["key"] for i in items for link in i["links"]}
        self.assertIn(named["key"], linked, "a ticket named by key must be linked")
        self.assertIn(missing, source["unresolved_keys"])
        self.assertNotIn("decision", {i["type"] for i in items if "release one week" in i["evidence"]})

        suggested = {s["key"] for i in items for s in i["suggested"]}
        print("suggested tickets:", sorted(suggested))
        self.assertIn(described["key"], suggested, "the described ticket should be suggested")

        # The PO approves everything and confirms the suggestion for the described ticket.
        links = {i["uid"]: [described["key"]] for i in items
                 if described["key"] in {s["key"] for s in i["suggested"]}}
        done = mn.review_source(self.ctx, SOURCE_ID, approve=[i["uid"] for i in items], reviewer="po-1",
                                links=links, inline=True)
        print("approved:", done["source"]["status"], "indexed:", done["indexed"])
        self.assertEqual(done["source"]["status"], mn.APPROVED)
        confirmed = {link["key"] for i in done["items"] for link in i["links"]}
        self.assertIn(described["key"], confirmed)

        if done["indexed"]:
            hits = mn.search_meetings("What did the client say about the release notes?", self.ctx)
            print("search:", [(h["title"], h["score"]) for h in hits])
            self.assertTrue(hits and hits[0]["title"] == "TAWOS release sync")

            from syntrace_ai.assistant.answer_generator import generate_answer_result
            answers = {}
            for question in (f"Why is {named['key']} blocked according to the meeting?",
                             "What did the client agree about the release notes in the meeting?"):
                answers[question] = answer = generate_answer_result(question, self.ctx)
                print(f"\nQ: {question}\nA [{answer['status']} / {answer.get('source')}]: {answer['answer']}")
            for answer in answers.values():
                self.assertEqual(answer["status"], "ok")
            blocked, notes = answers.values()
            self.assertIn("staging", blocked["answer"].lower())
            self.assertIn("english", notes["answer"].lower())

    def test_long_meeting_on_many_tickets(self):
        """A standup long enough to be split into several parts for the model: every ticket named by key
        must be linked, small talk must give no items, and duplicates across parts must be merged."""
        rows = run_query(
            "MATCH (w:WorkItem {tenant_id: $t, project_key: $p}) WHERE w.summary IS NOT NULL "
            "RETURN w.key AS key, w.summary AS summary ORDER BY w.key LIMIT 24", t=TENANT, p=self.project)
        reasons = ["the build server is slow", "we are waiting for the design review", "the API keys expired",
                   "QA found two regressions"]
        lines = []
        for n, row in enumerate(rows):
            lines.append(f"Speaker {n % 3 + 1}: Good morning everyone, how was the weekend? The coffee machine is broken again.")
            lines.append(f"Speaker {n % 3 + 1}: Update on {row['key']} ({row['summary']}): it is blocked because "
                         f"{reasons[n % len(reasons)]}.")
            lines.append(f"Speaker {(n + 1) % 3 + 1}: Okay, thanks. Let's move on.")
        lines.append("Client: To repeat it once more, the release notes will be in English only, we agreed on that.")
        transcript = "\n".join(lines)
        started = time.monotonic()
        result = mn.submit_source(self.ctx, SOURCE_ID, self.project, "online", "Long standup", "2026-11-06",
                                  text=transcript, inline=True)
        seconds = round(time.monotonic() - started, 1)
        source, items = result["source"], result["items"]
        parts = len(mn.split_text(transcript, mn.EXTRACT_CHARS, mn.EXTRACT_OVERLAP))
        linked = {link["key"] for i in items for link in i["links"]}
        expected = {row["key"] for row in rows}
        print(f"\nlong standup: {len(transcript)} chars, {parts} parts, {seconds}s, status {source['status']}, "
              f"{len(items)} items, rejected {source['rejected_items']}")
        print("missing links:", sorted(expected - linked))
        print("types:", {t: sum(1 for i in items if i["type"] == t) for t in mn.ITEM_TYPES})
        self.assertEqual(source["status"], mn.PENDING, source.get("error"))
        self.assertGreater(parts, 1)
        self.assertGreaterEqual(len(linked & expected) / len(expected), 0.9)
        self.assertFalse([i for i in items if "coffee" in i["evidence"].lower() or "weekend" in i["evidence"].lower()])
        self.assertLessEqual(sum(1 for i in items if "English only" in i["text"] or "English only" in i["evidence"]), 1)

    def test_ticket_suggestions_calibration(self):
        """How well a ticket described in other words is found, in English and in Arabic. Prints the
        numbers that set MEETING_LINK_MIN_SCORE and decide the language of item texts."""
        rows = run_query(
            "MATCH (w:WorkItem {tenant_id: $t, project_key: $p}) WHERE w.embedding IS NOT NULL "
            "AND size(w.summary) >= 25 RETURN w.key AS key, w.summary AS summary ORDER BY w.key LIMIT 40",
            t=TENANT, p=self.project)
        prompt = ("For each ticket, write how a client or developer would mention it in a meeting, without "
                  "the ticket key and without copying the title: one sentence in English (\"en\") and the same "
                  "in Egyptian Arabic with technical words in English (\"ar\"). Return only JSON: "
                  '{"items": [{"key": "...", "en": "...", "ar": "..."}]}\n'
                  + "\n".join(f"{r['key']}: {r['summary']}" for r in rows))
        said = {i["key"]: i for i in mn.parse_items(mn._llm(prompt)) if i.get("key")}
        self.assertGreaterEqual(len(said), 30)
        report = {}
        with unittest.mock.patch.object(mn, "MAX_SUGGESTIONS", 3), unittest.mock.patch.object(mn, "LINK_MIN_SCORE", 0.0):
            for lang in ("en", "ar"):
                cases = [(key, value[lang]) for key, value in said.items() if value.get(lang)]
                items = [{"text": text, "links": []} for _, text in cases]
                mn.suggest_links(items, self.ctx)
                scored = []
                for (key, text), item in zip(cases, items):
                    keys = [x["key"] for x in item["suggested"]]
                    right = next((x["score"] for x in item["suggested"] if x["key"] == key), None)
                    wrong = max((x["score"] for x in item["suggested"] if x["key"] != key), default=0.0)
                    top = item["suggested"][0]["score"] if item["suggested"] else 0.0
                    scored.append({"top1": bool(keys) and keys[0] == key, "top3": key in keys,
                                   "right": right, "wrong": wrong, "top": top,
                                   "gap": (top - item["suggested"][1]["score"]) if len(keys) > 1 else 1.0})
                report[lang] = scored
        for lang, scored in report.items():
            n = len(scored)
            print(f"\n[{lang}] {n} tickets: top1 {sum(x['top1'] for x in scored) / n:.0%}, "
                  f"top3 {sum(x['top3'] for x in scored) / n:.0%}")
            for threshold in (0.5, 0.55, 0.6, 0.65, 0.7):
                shown = [x for x in scored if x["top"] >= threshold]
                good = sum(x["top1"] for x in shown)
                print(f"  min {threshold}: first suggestion shown for {len(shown)}/{n}, right {good}/{len(shown) or 1}, "
                      f"right tickets lost {sum(x['top1'] for x in scored) - good}")
            for margin in (0.02, 0.03, 0.05):
                second_kept = [x for x in scored if x["gap"] <= margin]
                print(f"  second suggestion within {margin} of the first: {len(second_kept)}/{n}, "
                      f"of which the first was wrong {sum(not x['top1'] for x in second_kept)}")
        self.assertGreaterEqual(sum(x["top3"] for x in report["en"]) / len(report["en"]), 0.6)


if __name__ == "__main__":
    unittest.main()
