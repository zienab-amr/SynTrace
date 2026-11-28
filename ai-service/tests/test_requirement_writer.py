"""The second step: each requirement written as a user story, with checked priority and acceptance."""
import json
import unittest

from syntrace_ai.meetings import meeting_notes as mn
from syntrace_ai.meetings import writer as rw

TEXT = ("Sara Client: أهلًا.\n"
        "Sara Client: عايزين الـ users يعملوا login بالإيميل عشان مش عايزين نبعت SMS.\n"
        "Sara Client: ودي أهم حاجة عندنا، لازم الـ login ياخد أقل من تانيتين.\n"
        "Fatma (You): تمام.\n"
        "Sara Client: وعايزين dashboard حلو.\n")


def items():
    found = [{"type": "requirement", "text": "Users log in with email.",
              "evidence": "عايزين الـ users يعملوا login بالإيميل عشان مش عايزين نبعت SMS.", "needs_review": False},
             {"type": "requirement", "text": "A nice dashboard.", "evidence": "وعايزين dashboard حلو.",
              "needs_review": False},
             {"type": "action_item", "text": "Fatma confirms.", "evidence": "تمام.", "needs_review": False}]
    for i in found:
        i["lines"] = mn.evidence_lines(i["evidence"], TEXT)
    return found


def reply(rows):
    return lambda prompt: json.dumps({"requirements": rows}, ensure_ascii=False)


class WriterTests(unittest.TestCase):
    def test_story_priority_and_said_criteria_are_kept_when_the_quotes_are_real(self):
        found = items()
        error = rw.write(found, TEXT, "SYNT", reply([
            {"id": 0, "user_story": "As a user, I want to log in with my email, so that no SMS is needed.",
             "category": "functional", "clarity": "clear", "question": None, "priority": "high",
             "priority_quote": "ودي أهم حاجة عندنا",
             "acceptance_said": [{"criterion": "Login takes under two seconds.",
                                  "quote": "لازم الـ login ياخد أقل من تانيتين"}],
             "acceptance_suggested": ["A wrong password shows an error."]},
            {"id": 1, "user_story": "As a user, I want a dashboard.", "category": "non_functional",
             "clarity": "unclear", "question": "What should the dashboard show?", "priority": None,
             "acceptance_said": [], "acceptance_suggested": []}]))
        self.assertIsNone(error)
        login, dashboard, action = found
        self.assertEqual((login["priority"], login["category"]), ("high", "functional"))
        self.assertEqual(login["acceptance_said"][0]["criterion"], "Login takes under two seconds.")
        self.assertEqual(login["acceptance_suggested"], ["A wrong password shows an error."])
        self.assertEqual(dashboard["clarify_question"], "What should the dashboard show?")
        self.assertTrue(dashboard["needs_review"])
        self.assertNotIn("user_story", action)

    def test_a_suggestion_with_a_number_nobody_said_is_dropped(self):
        found = items()
        rw.write(found, TEXT, "SYNT", reply([{"id": 0, "acceptance_said": [
            {"criterion": "Login takes under two seconds.", "quote": "لازم الـ login ياخد أقل من تانيتين"}],
            "acceptance_suggested": ["Login succeeds within 2 seconds.",
                                     "Login works for 95% of attempts.",
                                     "A wrong password shows an error."]}]))
        # 2 seconds was said; 95% was not
        self.assertEqual(found[0]["acceptance_suggested"],
                         ["Login succeeds within 2 seconds.", "A wrong password shows an error."])

    def test_numbers_in_words_and_arabic_count(self):
        self.assertEqual(rw._numbers("under two seconds, أقل من تانيتين, ٣ days, 1,000 rows"), {"2", "3", "1000"})

    def test_a_limit_said_right_after_becomes_a_condition_of_the_requirement(self):
        source = ("Sara Client: عايزين voice commands بالعربي.\n"
                  "Sara Client: ولازم النتيجة تظهر في أقل من تانيتين.\n")
        found = [{"type": "requirement", "text": "Arabic voice commands.", "evidence": "عايزين voice commands بالعربي."},
                 {"type": "requirement", "text": "Voice results appear in under two seconds.",
                  "evidence": "ولازم النتيجة تظهر في أقل من تانيتين."}]
        for i in found:
            i["lines"] = mn.evidence_lines(i["evidence"], source)
        rw.write(found, source, "SYNT", reply([{"id": 0, "category": "functional"},
                                              {"id": 1, "category": "non_functional"}]))
        self.assertEqual(found[0]["acceptance_said"],
                         [{"criterion": "Voice results appear in under two seconds.",
                           "quote": "ولازم النتيجة تظهر في أقل من تانيتين."}])
        self.assertEqual(found[1].get("acceptance_said"), [])

    def test_a_limit_goes_only_to_the_requirement_it_is_about(self):
        # BE eval: "Arabic-only release notes" was said between the voice commands and their limit
        source = ("Sara Client: عايزين voice commands بالعربي.\n"
                  "Sara Client: والـ release notes تبقى عربي بس.\n"
                  "Sara Client: ولازم نتيجة الـ voice تظهر في أقل من تانيتين.\n")
        found = [{"type": "requirement", "text": "Arabic voice commands.", "evidence": "عايزين voice commands بالعربي."},
                 {"type": "requirement", "text": "Release notes in Arabic only.", "evidence": "والـ release notes تبقى عربي بس."},
                 {"type": "requirement", "text": "Voice results appear in under two seconds.",
                  "evidence": "ولازم نتيجة الـ voice تظهر في أقل من تانيتين."}]
        for i in found:
            i["lines"] = mn.evidence_lines(i["evidence"], source)
        rw.write(found, source, "SYNT", reply([{"id": 0, "category": "functional"}, {"id": 1, "category": "non_functional"},
                                              {"id": 2, "category": "non_functional"}]))
        self.assertEqual([s["criterion"] for s in found[0]["acceptance_said"]], ["Voice results appear in under two seconds."])
        self.assertEqual(found[1].get("acceptance_said"), [])

    def test_a_cut_off_reply_keeps_its_whole_rows_and_asks_again_for_the_rest(self):
        # BE eval: the model ran out of tokens in the middle of the fifth requirement
        found = items()
        replies = ['{"requirements": [{"id": 0, "user_story": "As a user, I want to log in with my email."}, '
                   '{"id": 1, "user_story": "As a user, I want a dash',
                   '{"requirements": [{"id": 0, "user_story": "As a manager, I want a dashboard."}]}']
        prompts = []

        def llm(prompt):
            prompts.append(prompt)
            return replies[len(prompts) - 1]
        error = rw.write(found, TEXT, "SYNT", llm)
        self.assertIsNone(error)
        self.assertEqual(found[0]["user_story"], "As a user, I want to log in with my email.")
        self.assertEqual(found[1]["user_story"], "As a manager, I want a dashboard.")
        self.assertEqual(len(prompts), 2)
        self.assertNotIn("Requirement id 1", prompts[1])   # only the one left out, as id 0

    def test_a_requirement_left_out_twice_is_reported(self):
        found = items()
        def llm(prompt):   # never answers for the dashboard
            rows = [{"id": 0, "user_story": "As a user, I want to log in."}] if "Users log in" in prompt else []
            return json.dumps({"requirements": rows})
        error = rw.write(found, TEXT, "SYNT", llm)
        self.assertEqual(error, "1 requirement(s) could not be written")

    def test_a_story_without_the_article_is_fixed(self):
        found = items()
        rw.write(found, TEXT, "SYNT", reply([{"id": 0, "user_story": "As user, I want to log in."},
                                            {"id": 1, "user_story": "As admin, I want a dashboard."}]))
        self.assertEqual((found[0]["user_story"], found[1]["user_story"]),
                         ("As a user, I want to log in.", "As an admin, I want a dashboard."))

    def test_a_priority_nobody_said_is_dropped(self):
        found = items()
        rw.write(found, TEXT, "SYNT", reply([{"id": 1, "user_story": "As a user, I want a dashboard.",
                                             "priority": "high", "priority_quote": "the dashboard is urgent"}]))
        self.assertIsNone(found[1]["priority"])

    def test_a_said_criterion_with_an_invented_quote_becomes_a_suggestion(self):
        found = items()
        rw.write(found, TEXT, "SYNT", reply([{"id": 0, "acceptance_said": [
            {"criterion": "Works offline.", "quote": "لازم يشتغل من غير نت"}]}]))
        self.assertEqual(found[0]["acceptance_said"], [])
        self.assertEqual(found[0]["acceptance_suggested"], ["Works offline."])

    def test_a_failed_model_keeps_the_items_and_reports(self):
        def broken(prompt):
            raise RuntimeError("down")
        found = items()
        self.assertEqual(rw.write(found, TEXT, "SYNT", broken), "2 requirement(s) could not be written")
        self.assertEqual(found[0]["text"], "Users log in with email.")

    def test_the_prompt_holds_the_lines_around_the_quote(self):
        prompts = []
        rw.write(items(), TEXT, "SYNT", lambda p: prompts.append(p) or "{}")
        self.assertIn("3: Sara Client: ودي أهم حاجة عندنا", prompts[0])

    def test_stored_and_read_back(self):
        found = items()
        rw.write(found, TEXT, "SYNT", reply([{"id": 0, "acceptance_said": [
            {"criterion": "Fast.", "quote": "لازم الـ login ياخد أقل من تانيتين"}]}]))
        props = rw.node_props(found[0])
        self.assertIsInstance(props["acceptance_said"], str)
        self.assertEqual(rw.from_node(dict(props))["acceptance_said"][0]["criterion"], "Fast.")


class BlameGuardTests(unittest.TestCase):
    def test_blame_about_a_person_is_refused(self):
        index = mn.evidence_index("Sara: بصراحة إيهاب اتأخر علينا تاني ومش مركز معانا خالص.")
        item, reason = mn.check_item({"type": "blocker", "text": "Ihab is delayed, causing a blockage.",
                                      "evidence": "إيهاب اتأخر علينا تاني ومش مركز معانا خالص."}, index)
        self.assertIsNone(item)
        self.assertEqual(reason, "blame or judgement about a person")

    def test_a_neutral_work_problem_stays(self):
        index = mn.evidence_index("Martina: أنا مستنية الـ Jira setup عشان أشغل المشروع.")
        item, _ = mn.check_item({"type": "blocker", "text": "Martina is waiting for the Jira setup.",
                                 "evidence": "أنا مستنية الـ Jira setup عشان أشغل المشروع."}, index)
        self.assertIsNotNone(item)


if __name__ == "__main__":
    unittest.main()


class UnitTests(unittest.TestCase):
    def test_a_criterion_that_changed_the_unit_is_dropped(self):
        from syntrace_ai.meetings import text as tx
        self.assertFalse(tx.same_units("Result appears in less than two minutes.", "النتيجة تظهر في أقل من تانيتين"))
        self.assertTrue(tx.same_units("Results in under two seconds.", "النتيجة تظهر في أقل من تانيتين"))
        self.assertTrue(tx.same_units("Works on iOS and Android.", "الاتنين"))
        self.assertTrue(tx.same_units("Export within one day.", "خلال يوم واحد"))
