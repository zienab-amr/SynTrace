"""SYNT-926: the fallback on a second Groq account (GROQ_FALLBACK_API_KEY), or another model."""
import os
import unittest
from unittest.mock import patch

from syntrace_ai.assistant import answer_generator as ag
from syntrace_ai.assistant import graph_agent as ga
from syntrace_ai.assistant import llm_client


class RateLimitError(Exception):
    pass


def client(name, calls, fail=False):
    class Completions:
        @staticmethod
        def create(**kw):
            calls.append((name, kw["model"]))
            if fail:
                raise RateLimitError("Rate limit reached ... tokens per day ... try again in 9m3s")
            message = type("M", (), {"content": "ok", "tool_calls": None})()
            return type("C", (), {"choices": [type("Ch", (), {"message": message})()], "usage": None})()
    return type("Client", (), {"chat": type("Chat", (), {"completions": Completions})()})()


class FallbackAccountTests(unittest.TestCase):
    def setUp(self):   # a used-up day remembered by another test must not move these calls
        ag._MAIN_USED_UNTIL = 0.0
        self.addCleanup(setattr, ag, "_MAIN_USED_UNTIL", 0.0)

    def env(self, **values):
        base = {"GROQ_FALLBACK_API_KEY": "", "GROQ_FALLBACK_MODEL": ""}
        base.update(values)
        return patch.dict(os.environ, base)

    def test_which_fallback(self):
        with self.env():
            self.assertIsNone(ag.fallback_model("gpt"))
        with self.env(GROQ_FALLBACK_MODEL="qwen"):
            self.assertEqual(ag.fallback_model("gpt"), "qwen")                       # another model, same account
        with self.env(GROQ_FALLBACK_API_KEY="k2"):
            self.assertEqual(ag.fallback_model("gpt"), ag.FALLBACK_ACCOUNT + "gpt")  # the same model, account 2
        with self.env(GROQ_FALLBACK_API_KEY="k2", GROQ_FALLBACK_MODEL="qwen"):
            self.assertEqual(ag.fallback_model("gpt"), ag.FALLBACK_ACCOUNT + "qwen")

    def test_the_answer_moves_to_the_second_account_with_the_same_model(self):
        calls = []
        with self.env(GROQ_FALLBACK_API_KEY="k2"), \
                patch.object(ag, "_get_client", return_value=client("main", calls, fail=True)), \
                patch.object(ag, "_fallback_client", return_value=client("second", calls)), \
                patch.object(ag, "count_tokens"):
            self.assertEqual(ag._complete("q"), "ok")
        self.assertEqual(calls, [("main", ag.GROQ_MODEL), ("second", ag.GROQ_MODEL)])

    def test_the_agent_moves_to_the_second_account(self):
        calls = []
        with self.env(GROQ_FALLBACK_API_KEY="k2"), \
                patch.object(ag, "_get_client", return_value=client("main", calls, fail=True)), \
                patch.object(ag, "_fallback_client", return_value=client("second", calls)), \
                patch.object(ag, "count_tokens"):
            self.assertIsNotNone(ga._ask([{"role": "user", "content": "q"}], False))
        self.assertEqual([c[0] for c in calls], ["main", "second"])

    def test_meeting_steps_list_the_second_account(self):
        with self.env(GROQ_FALLBACK_API_KEY="k2", MEETING_COMPARE_PROVIDER="groq", MEETING_COMPARE_MODEL=""):
            provider, models = llm_client.settings("compare")
        self.assertEqual(models, [ag.GROQ_MODEL, ag.FALLBACK_ACCOUNT + ag.GROQ_MODEL])


if __name__ == "__main__":
    unittest.main()


class OpenRouterFallbackKeyTests(unittest.TestCase):
    """SYNT-1050: ERNIE's 50 free requests a day are per key; OPENROUTER_FALLBACK_API_KEY takes over."""

    def setUp(self):
        llm_client._USED_UP_KEYS.clear()
        self.addCleanup(llm_client._USED_UP_KEYS.clear)

    def run_with(self, results, **env):
        calls = []

        def fake(name, url, key_env, timeout, model, prompt, temperature, headers=None):
            calls.append(key_env)
            result = results[key_env]
            if isinstance(result, Exception):
                raise result
            return result
        values = {"OPENROUTER_API_KEY": "main", "OPENROUTER_FALLBACK_API_KEY": ""}
        values.update(env)
        with patch.dict(os.environ, values), patch.object(llm_client, "_openai_compatible", fake):
            try:
                return llm_client._openrouter("ernie", "p", 0), calls
            except llm_client.RateLimited as exc:
                return exc, calls

    def used_up(self):
        return llm_client.RateLimited("openrouter daily limit used up", 9e9)

    def test_a_used_up_main_key_moves_to_the_fallback_key(self):
        reply, calls = self.run_with({"OPENROUTER_API_KEY": self.used_up(), "OPENROUTER_FALLBACK_API_KEY": "ok"},
                                     OPENROUTER_FALLBACK_API_KEY="second")
        self.assertEqual((reply, calls), ("ok", ["OPENROUTER_API_KEY", "OPENROUTER_FALLBACK_API_KEY"]))
        reply, calls = self.run_with({"OPENROUTER_API_KEY": "never", "OPENROUTER_FALLBACK_API_KEY": "again"},
                                     OPENROUTER_FALLBACK_API_KEY="second")
        self.assertEqual((reply, calls), ("again", ["OPENROUTER_FALLBACK_API_KEY"]))   # the used-up key waits

    def test_a_busy_moment_does_not_spend_the_fallback_key(self):
        busy = llm_client.RateLimited("openrouter rate limit")
        reply, calls = self.run_with({"OPENROUTER_API_KEY": busy, "OPENROUTER_FALLBACK_API_KEY": "ok"},
                                     OPENROUTER_FALLBACK_API_KEY="second")
        self.assertIsInstance(reply, llm_client.RateLimited)
        self.assertEqual(calls, ["OPENROUTER_API_KEY"])

    def test_both_keys_used_up_says_so(self):
        reply, calls = self.run_with({"OPENROUTER_API_KEY": self.used_up(),
                                      "OPENROUTER_FALLBACK_API_KEY": self.used_up()},
                                     OPENROUTER_FALLBACK_API_KEY="second")
        self.assertIsInstance(reply, llm_client.RateLimited)
        self.assertTrue(reply.until)
        self.assertEqual(len(calls), 2)

    def test_without_a_fallback_key_only_the_main_key_is_used(self):
        reply, calls = self.run_with({"OPENROUTER_API_KEY": self.used_up()})
        self.assertIsInstance(reply, llm_client.RateLimited)
        self.assertEqual(calls, ["OPENROUTER_API_KEY"])

    def test_the_day_budget_counts_both_keys(self):
        with patch.dict(os.environ, {"OPENROUTER_API_KEY": "main", "OPENROUTER_FALLBACK_API_KEY": "second",
                                     "OPENROUTER_DAILY_LIMIT": ""}):
            os.environ.pop("OPENROUTER_DAILY_LIMIT")
            self.assertEqual(llm_client._daily_limit("openrouter"), 100)
        with patch.dict(os.environ, {"OPENROUTER_API_KEY": "main", "OPENROUTER_FALLBACK_API_KEY": ""}):
            os.environ.pop("OPENROUTER_DAILY_LIMIT", None)
            self.assertEqual(llm_client._daily_limit("openrouter"), 50)


class MainAccountRestsTests(unittest.TestCase):
    """SYNT-1054: once Groq says the main account's DAY is used up, calls go straight to the fallback."""

    def setUp(self):
        ag._MAIN_USED_UNTIL = 0.0
        self.addCleanup(setattr, ag, "_MAIN_USED_UNTIL", 0.0)

    def day_error(self):
        return type("RateLimitError", (Exception,), {})(
            "Rate limit reached ... on tokens per day (TPD): Limit 200000, Used 199955. Please try again in 35m36.24s.")

    def test_a_used_up_day_sends_every_call_to_the_fallback(self):
        with patch.dict(os.environ, {"GROQ_FALLBACK_API_KEY": "second", "GROQ_FALLBACK_MODEL": ""}):
            self.assertEqual(ag.routes("main"), ["main", ag.FALLBACK_ACCOUNT + "main"])
            ag.note_limit(self.day_error(), "main")
            self.assertEqual(ag.routes("main"), [ag.FALLBACK_ACCOUNT + "main"])
            self.assertTrue(ag.main_resting("main"))
            self.assertFalse(ag.main_resting(ag.FALLBACK_ACCOUNT + "main"))
            import time
            self.assertAlmostEqual(ag._MAIN_USED_UNTIL - time.time(), 35 * 60 + 36.24, delta=5)

    def test_a_per_minute_limit_or_the_fallback_own_limit_changes_nothing(self):
        minute = type("RateLimitError", (Exception,), {})("on tokens per minute (TPM): try again in 3.2s")
        with patch.dict(os.environ, {"GROQ_FALLBACK_API_KEY": "second"}):
            ag.note_limit(minute, "main")
            ag.note_limit(self.day_error(), ag.FALLBACK_ACCOUNT + "main")
            self.assertEqual(len(ag.routes("main")), 2)

    def test_without_a_fallback_account_the_main_one_is_still_tried(self):
        with patch.dict(os.environ, {"GROQ_FALLBACK_API_KEY": "", "GROQ_FALLBACK_MODEL": ""}):
            ag.note_limit(self.day_error(), "main")
            self.assertEqual(ag.routes("main"), ["main"])
            self.assertFalse(ag.main_resting("main"))
