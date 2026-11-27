"""SYNT-1058: the long-context model reads a meeting twice (MEETING_READS=2) and the readings are merged."""
import os
import unittest
from unittest.mock import patch

from syntrace_ai.meetings import merge


def item(text, lines, kind="requirement", owner=None):
    return {"type": kind, "text": text, "lines": lines, "evidence": text, "owner": owner, "needs_review": False}


class MergeTests(unittest.TestCase):
    def test_both_readings_once_and_each_reading_alone_for_review(self):
        first = [item("Users log in with email.", [3]), item("Ship on Friday.", [9], "decision")]
        second = [item("Users must log in with their email.", [3]), item("Add dark mode.", [14])]
        out, counts = merge.merge(first, second)
        self.assertEqual([i["text"] for i in out], ["Users log in with email.", "Ship on Friday.", "Add dark mode."])
        self.assertEqual([i["needs_review"] for i in out], [False, True, True])
        self.assertEqual(counts, {"both": 1, "first_only": 1, "second_only": 1, "type_disagreed": 0})

    def test_a_point_typed_differently_is_flagged_and_an_owner_is_kept(self):
        first = [item("Look into the logo.", [7], "action_item")]
        second = [item("Look into the company logo.", [7], "requirement", owner="Marketing")]
        out, counts = merge.merge(first, second)
        self.assertEqual(len(out), 1)
        self.assertTrue(out[0]["needs_review"])
        self.assertEqual(out[0]["owner"], "Marketing")
        self.assertEqual(counts["type_disagreed"], 1)

    def test_different_lines_are_different_points(self):
        out, _ = merge.merge([item("Use Redis.", [4])], [item("Use Redis.", [40])])
        self.assertEqual(len(out), 2)


class ReadTwiceTests(unittest.TestCase):
    def setUp(self):
        from syntrace_ai.meetings import meeting_notes as mn
        self.mn = mn
        self.calls = []

        def fake_find(text, project, source_type, title, meeting_date, llm=None, glossary=(), size=None,
                      meta=None, second=False):
            self.calls.append(second)
            if second:
                return [item("Add dark mode.", [2])], 1
            return [item("Users log in with email.", [1])], 0
        self.patches = [patch.object(mn, "_find_items", fake_find), patch.object(mn, "part_chars", lambda: 400000)]
        for p in self.patches:
            p.start()
            self.addCleanup(p.stop)

    def run_extract(self, **env):
        values = {"MEETING_READS": "", "GROQ_API_KEY": "k", "MEETING_SHORT_CHARS": "10", "MEETING_CLASSIFY": ""}
        values.update(env)
        meta = {}
        with patch.dict(os.environ, values):
            items, rejected = self.mn.extract_items("line one\nline two that is long", "P", "online", "t", None,
                                                    meta=meta)
        return items, rejected, meta

    def test_read_twice_by_default(self):
        items, rejected, meta = self.run_extract()
        self.assertEqual(self.calls, [False, True])
        self.assertEqual(len(items), 2)
        self.assertEqual(rejected, 1)
        self.assertEqual(meta["readings"]["both"], 0)

    def test_once_when_asked(self):
        items, _, _ = self.run_extract(MEETING_READS="1")
        self.assertEqual(self.calls, [False])
        self.assertEqual(len(items), 1)

    def test_a_short_meeting_on_groq_is_read_once(self):
        self.run_extract(MEETING_SHORT_CHARS="100000")
        self.assertEqual(self.calls, [False])

    def test_a_failed_second_reading_keeps_the_first(self):
        from syntrace_ai.meetings.errors import ExtractionUnavailable

        def fails(*a, second=False, **k):
            self.calls.append(second)
            if second:
                raise ExtractionUnavailable("busy")
            return [item("Users log in with email.", [1])], 0
        with patch.object(self.mn, "_find_items", fails):
            items, _, meta = self.run_extract()
        self.assertEqual(len(items), 1)
        self.assertNotIn("readings", meta)


if __name__ == "__main__":
    unittest.main()


class ReviewModeTests(unittest.TestCase):
    def test_only_the_missing_points_are_added_for_review(self):
        found = [item("Users log in with email.", [3])]
        missing = [item("Users log in with their email.", [3]), item("Add dark mode.", [14])]
        out, counts = merge.add_missing(found, missing)
        self.assertEqual([i["text"] for i in out], ["Users log in with email.", "Add dark mode."])
        self.assertEqual([i["needs_review"] for i in out], [False, True])
        self.assertEqual(counts, {"first": 1, "added": 1, "repeated": 1})

    def test_the_review_prompt_lists_what_was_found(self):
        from syntrace_ai.meetings import meeting_notes as mn
        listing = mn._found_list([item("Users log in with email.", [3, 4])])
        self.assertEqual(listing, "1. [requirement] Users log in with email. (line 3)")
        self.assertIn("{found}", mn.REVIEW_READING)
        with patch.dict(os.environ, {"MEETING_SECOND_MODE": "review"}):
            self.assertEqual(mn.second_mode(), "review")
        with patch.dict(os.environ, {"MEETING_SECOND_MODE": "x"}):
            self.assertEqual(mn.second_mode(), "again")
