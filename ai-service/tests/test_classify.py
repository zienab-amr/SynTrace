"""SYNT-1053: ERNIE finds the points, gpt-oss judges type, proposal and owner (MEETING_CLASSIFY=groq)."""
import json
import os
import unittest
from unittest.mock import patch

from syntrace_ai.meetings import classify

ITEMS = [
    {"type": "requirement", "text": "Use Cedar as the policy engine.", "owner": None, "needs_review": False,
     "evidence": "we are proposing Cedar as the engine"},
    {"type": "decision", "text": "Proposed: Ship the beta on Friday.", "owner": None, "needs_review": True,
     "evidence": "okay so we ship the beta on Friday then"},
    {"type": "action_item", "text": "Look into instruction manuals.", "owner": None, "needs_review": False,
     "evidence": "like marketing to look at instruction manuals"},
]


def owner_ok(owner, item):
    return owner.lower() in item["evidence"].lower()


def reply(rows):
    return lambda prompt: json.dumps({"items": rows})


class ClassifyTests(unittest.TestCase):
    def test_the_second_look_sets_type_mark_and_owner(self):
        out = classify.classify(ITEMS, reply([
            {"n": 1, "type": "requirement", "proposed": True, "owner": None},
            {"n": 2, "type": "decision", "proposed": False, "owner": None},
            {"n": 3, "type": "action_item", "proposed": False, "owner": "Marketing"}]), "meeting", "P", owner_ok)
        self.assertEqual(out[0]["text"], "Proposed: Use Cedar as the policy engine.")
        self.assertTrue(out[0]["needs_review"])
        self.assertEqual(out[1]["text"], "Ship the beta on Friday.")
        self.assertEqual(out[2]["owner"], "Marketing")
        self.assertEqual([i["evidence"] for i in out], [i["evidence"] for i in ITEMS])   # quotes never change

    def test_a_guessed_owner_or_a_bad_type_is_not_taken(self):
        out = classify.classify(ITEMS, reply([
            {"n": 1, "type": "wish", "proposed": False},
            {"n": 3, "type": "action_item", "owner": "Zeinab"}]), "meeting", "P", owner_ok)
        self.assertEqual(out[0]["type"], "requirement")
        self.assertIsNone(out[2]["owner"])
        self.assertEqual(out[1], ITEMS[1])   # no row for it: left as found

    def test_only_requirements_and_decisions_can_be_proposed(self):
        out = classify.classify(ITEMS[2:], reply([{"n": 1, "type": "action_item", "proposed": True}]),
                                "meeting", "P", owner_ok)
        self.assertFalse(out[0]["text"].startswith("Proposed"))

    def test_a_broken_reply_keeps_the_items(self):
        self.assertEqual(classify.classify(ITEMS, lambda p: "sorry", "meeting", "P", owner_ok), ITEMS)

        def fails(prompt):
            raise RuntimeError("429")
        self.assertEqual(classify.classify(ITEMS, fails, "meeting", "P", owner_ok), ITEMS)

    def test_the_prompt_numbers_items_and_drops_the_mark(self):
        seen = []
        classify.classify(ITEMS, lambda p: seen.append(p) or "{}", "meeting transcript", "SynTrace", owner_ok)
        self.assertIn('"n": 2, "type": "decision", "text": "Ship the beta on Friday."', seen[0])
        self.assertIn('the project "SynTrace"', seen[0])

    def test_big_meetings_go_in_batches(self):
        calls = []
        many = [dict(ITEMS[0], text=f"Point {n}.") for n in range(classify.BATCH + 5)]
        classify.classify(many, lambda p: calls.append(p) or '{"items": []}', "meeting", "P", owner_ok)
        self.assertEqual(len(calls), 2)
        self.assertIn(f'"n": {classify.BATCH + 1}', calls[1])

    def test_off_unless_asked(self):
        with patch.dict(os.environ, {"MEETING_CLASSIFY": "", "GROQ_API_KEY": "k"}):
            self.assertFalse(classify.enabled())
        with patch.dict(os.environ, {"MEETING_CLASSIFY": "groq", "GROQ_API_KEY": "k"}):
            self.assertTrue(classify.enabled())


if __name__ == "__main__":
    unittest.main()


class ClassifyStepTests(unittest.TestCase):
    def test_classify_is_a_model_step_on_groq(self):
        from syntrace_ai.assistant import llm_client
        with patch.dict(os.environ, {"MEETING_CLASSIFY_PROVIDER": ""}):
            self.assertEqual(llm_client.settings("classify")[0], "groq")


class ParseTests(unittest.TestCase):
    def test_the_items_object_is_found_inside_words_and_fences(self):
        reply = 'Here {not json} you go:\n```json\n{"items": [{"n": 1, "type": "decision"}]}\n```'
        self.assertEqual(classify._parse(reply)[1]["type"], "decision")

    def test_a_broken_reply_is_asked_again_once(self):
        replies = iter(["oops", json.dumps({"items": [{"n": 1, "type": "decision", "proposed": False}]})])
        out = classify.classify(ITEMS[:1], lambda p: next(replies), "meeting", "P", owner_ok)
        self.assertEqual(out[0]["type"], "decision")


class NextLinesTests(unittest.TestCase):
    def test_each_item_carries_the_lines_said_after_its_quote(self):
        source = "A: we could use Redis\nB: yeah let's go with Redis\nC: ok\nD: next topic\nE: later"
        item = dict(ITEMS[0], lines=[1])
        listing = classify._listing([item], 1, source.split("\n"))
        self.assertIn('"next": "B: yeah let\'s go with Redis | C: ok | D: next topic"', listing)

    def test_no_lines_no_next(self):
        self.assertNotIn('"next"', classify._listing([ITEMS[0]], 1, None))
