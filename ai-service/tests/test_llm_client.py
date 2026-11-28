"""llm_client: provider and model per step from config, fallback, rate-limit waits."""
import os
import time
import unittest
from unittest import mock

from syntrace_ai.assistant import answer_generator as ag
from syntrace_ai.assistant import llm_client as lc


def _completion(text):
    msg = mock.Mock(content=text)
    return mock.Mock(choices=[mock.Mock(message=msg)])



class FreshLLM(unittest.TestCase):
    """Each test starts with no provider marked busy and no requests counted today."""
    def run(self, result=None):
        from syntrace_ai.assistant import llm_client
        llm_client._BUSY.clear()
        llm_client._USED.clear()
        llm_client._USED_UP_KEYS.clear()
        return super().run(result)

class RateLimitError(Exception):
    pass


class SettingsTests(FreshLLM):
    def test_defaults_to_groq_and_the_main_model(self):
        with mock.patch.dict(os.environ, {"GROQ_FALLBACK_MODEL": ""}, clear=False), \
                mock.patch.object(ag, "GROQ_MODEL", "openai/gpt-oss-120b"):
            os.environ.pop("MEETING_EXTRACT_PROVIDER", None)
            os.environ.pop("MEETING_EXTRACT_MODEL", None)
            self.assertEqual(lc.settings("extract"), ("groq", ["openai/gpt-oss-120b"]))

    def test_one_step_on_gemini_the_others_unchanged(self):
        env = {"MEETING_PLAN_PROVIDER": "gemini", "GEMINI_MODEL": "gemini-x", "GEMINI_FALLBACK_MODEL": "",
               "GROQ_FALLBACK_MODEL": "", "GEMINI_API_KEY": "k"}
        with mock.patch.dict(os.environ, env), mock.patch.object(ag, "GROQ_MODEL", "main"):
            self.assertEqual(lc.settings("plan"), ("gemini", ["gemini-x"]))
            os.environ.pop("MEETING_COMPARE_PROVIDER", None)
            self.assertEqual(lc.settings("compare")[0], "groq")

    def test_a_provider_override_uses_that_providers_default_model(self):
        env = {"MEETING_EXTRACT_PROVIDER": "gemini", "MEETING_EXTRACT_MODEL": "gemini-x", "GEMINI_API_KEY": "k",
               "GROQ_FALLBACK_MODEL": ""}
        with mock.patch.dict(os.environ, env), mock.patch.object(ag, "GROQ_MODEL", "main"):
            self.assertEqual(lc.settings("extract", "groq"), ("groq", ["main"]))
            self.assertEqual(lc.settings("extract")[1][0], "gemini-x")

    def test_bad_config_fails_early(self):
        with mock.patch.dict(os.environ, {"MEETING_SESSION_PROVIDER": "openai"}):
            with self.assertRaises(ValueError):
                lc.for_step("session")
        with self.assertRaises(ValueError):
            lc.settings("unknown")


class CompleteTests(FreshLLM):
    def test_groq_reply_and_fallback(self):
        calls = []

        def create(model, **_):
            calls.append(model)
            if model == "main":
                raise RuntimeError("down")
            return _completion("ok")
        client = mock.Mock()
        client.chat.completions.create.side_effect = create
        with mock.patch.multiple(ag, GROQ_MODEL="main", _get_client=lambda: client, count_tokens=lambda *a, **k: None), \
                mock.patch.dict(os.environ, {"GROQ_FALLBACK_MODEL": "backup", "MEETING_EXTRACT_PROVIDER": "groq"}):
            os.environ.pop("MEETING_EXTRACT_MODEL", None)
            self.assertEqual(lc.complete("extract", "p", wait=0), "ok")
        self.assertEqual(calls, ["main", "backup"])

    def test_rate_limit_waits_then_gives_up_with_the_reason(self):
        client = mock.Mock()
        client.chat.completions.create.side_effect = RateLimitError("429")
        with mock.patch.multiple(ag, GROQ_MODEL="main", _get_client=lambda: client), \
                mock.patch.dict(os.environ, {"GROQ_FALLBACK_MODEL": ""}):
            os.environ.pop("MEETING_COMPARE_PROVIDER", None)
            os.environ.pop("MEETING_COMPARE_MODEL", None)
            with self.assertRaises(lc.LLMUnavailable) as caught:
                lc.complete("compare", "p", attempts=2, wait=0)
        self.assertTrue(caught.exception.rate_limited)
        self.assertEqual(client.chat.completions.create.call_count, 2)

    def test_gemini_through_its_openai_endpoint(self):
        response = mock.Mock(status_code=200)
        response.json.return_value = {"choices": [{"message": {"content": "hi"}}]}
        env = {"MEETING_SESSION_PROVIDER": "gemini", "GEMINI_API_KEY": "k", "GEMINI_MODEL": "g",
               "GEMINI_FALLBACK_MODEL": ""}
        with mock.patch.dict(os.environ, env), mock.patch("requests.post", return_value=response) as post:
            os.environ.pop("MEETING_SESSION_MODEL", None)
            self.assertEqual(lc.complete("session", "p", wait=0), "hi")
        self.assertEqual(post.call_args.kwargs["json"]["model"], "g")
        self.assertEqual(post.call_args.kwargs["headers"]["Authorization"], "Bearer k")

    def test_gemini_without_a_key_falls_back_to_groq(self):
        env = {"MEETING_EXTRACT_PROVIDER": "gemini", "GEMINI_API_KEY": "", "GROQ_FALLBACK_MODEL": ""}
        with mock.patch.dict(os.environ, env), mock.patch.object(ag, "GROQ_MODEL", "main"):
            self.assertEqual(lc.settings("extract"), ("groq", ["main"]))

    def test_gemini_call_without_a_key_says_so(self):
        with mock.patch.dict(os.environ, {"GEMINI_API_KEY": ""}):
            with self.assertRaises(lc.LLMUnavailable) as caught:
                lc._gemini("m", "p", 0)
        self.assertIn("GEMINI_API_KEY", str(caught.exception))

    def test_gemini_429_is_a_rate_limit(self):
        response = mock.Mock(status_code=429)
        env = {"MEETING_SESSION_PROVIDER": "gemini", "GEMINI_API_KEY": "k", "GEMINI_FALLBACK_MODEL": "", "GROQ_API_KEY": ""}
        with mock.patch.dict(os.environ, env), mock.patch("requests.post", return_value=response):
            with self.assertRaises(lc.LLMUnavailable) as caught:
                lc.complete("session", "p", attempts=1, wait=0)
        self.assertTrue(caught.exception.rate_limited)


class StepFallbackTests(FreshLLM):
    def test_a_short_step_finishes_on_groq_when_gemini_is_down(self):
        env = {"MEETING_PLAN_PROVIDER": "gemini", "GEMINI_API_KEY": "k", "GROQ_API_KEY": "g",
               "GEMINI_FALLBACK_MODEL": "", "GROQ_FALLBACK_MODEL": ""}
        groq = mock.Mock(return_value="from groq")
        calls = {"gemini": mock.Mock(side_effect=TimeoutError()), "groq": groq}
        with mock.patch.dict(os.environ, env), mock.patch.dict(lc.CALLS, calls), mock.patch.object(ag, "GROQ_MODEL", "main"):
            self.assertEqual(lc.complete("plan", "p", attempts=1, wait=0), "from groq")
        self.assertEqual(groq.call_args.args[0], "main")

    def test_extraction_does_not_fall_back_here(self):
        env = {"MEETING_EXTRACT_PROVIDER": "gemini", "GEMINI_API_KEY": "k", "GROQ_API_KEY": "g", "GEMINI_FALLBACK_MODEL": ""}
        groq = mock.Mock(return_value="from groq")
        with mock.patch.dict(os.environ, env), mock.patch.dict(lc.CALLS, {"gemini": mock.Mock(side_effect=TimeoutError()), "groq": groq}):
            with self.assertRaises(lc.LLMUnavailable):
                lc.complete("extract", "p", attempts=1, wait=0)
        groq.assert_not_called()


class OpenRouterTests(FreshLLM):
    def test_openrouter_reads_a_whole_meeting_with_its_own_model(self):
        env = {"MEETING_EXTRACT_PROVIDER": "openrouter", "OPENROUTER_API_KEY": "k", "OPENROUTER_MODEL": "",
               "OPENROUTER_FALLBACK_MODEL": "", "MEETING_EXTRACT_MODEL": ""}
        with mock.patch.dict(os.environ, env):
            os.environ.pop("OPENROUTER_MODEL")
            provider, models = lc.settings("extract")
        self.assertEqual((provider, models), ("openrouter", ["baidu/ernie-5.5-flash-preview:free"]))
        self.assertIn("openrouter", lc.LONG_CONTEXT)

    def test_without_a_key_it_is_groq(self):
        with mock.patch.dict(os.environ, {"MEETING_PLAN_PROVIDER": "openrouter", "OPENROUTER_API_KEY": ""}):
            self.assertEqual(lc.settings("plan")[0], "groq")

    def test_an_error_inside_a_200_reply_is_busy(self):
        response = mock.Mock(status_code=200, json=lambda: {"error": {"code": 429}})
        with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": "k"}), mock.patch("requests.post", return_value=response):
            with self.assertRaises(lc.RateLimited):
                lc._openrouter("m", "p", 0)

    def test_the_reply_text_and_the_key_header(self):
        response = mock.Mock(status_code=200, json=lambda: {"choices": [{"message": {"content": "hi"}}]})
        with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": "k"}), mock.patch("requests.post", return_value=response) as post:
            self.assertEqual(lc._openrouter("m", "p", 0), "hi")
        self.assertEqual(post.call_args.kwargs["headers"]["Authorization"], "Bearer k")
        self.assertEqual(post.call_args.kwargs["json"]["model"], "m")


class OllamaTests(FreshLLM):
    def test_local_model_reads_in_parts(self):
        with mock.patch.dict(os.environ, {"MEETING_EXTRACT_PROVIDER": "ollama", "MEETING_EXTRACT_MODEL": ""}):
            self.assertEqual(lc.settings("extract"), ("ollama", ["qwen2.5:7b"]))
        self.assertNotIn("ollama", lc.LONG_CONTEXT)

    def test_the_context_size_is_sent(self):
        response = mock.Mock(status_code=200, json=lambda: {"message": {"content": "hi"}})
        with mock.patch("requests.post", return_value=response) as post:
            self.assertEqual(lc._ollama("m", "p", 0), "hi")
        self.assertEqual(post.call_args.kwargs["json"]["options"]["num_ctx"], lc.OLLAMA_CONTEXT)
        self.assertTrue(post.call_args.args[0].endswith("/api/chat"))


class BackoffTests(FreshLLM):
    def test_waits_double_and_stop_at_the_cap(self):
        with mock.patch("random.uniform", return_value=1.0):
            self.assertEqual([lc.backoff(20, n) for n in range(5)], [20, 40, 80, lc.MAX_WAIT, lc.MAX_WAIT])
            self.assertEqual(lc.backoff(0, 3), 0)


class AgentStepsTests(FreshLLM):
    def test_analyze_uses_a_model_per_step(self):
        from syntrace_ai.meetings import meeting_agent as ma
        seen = []
        models = {"compare": lambda p: seen.append("compare") or '{"items": []}',
                  "plan": lambda p: seen.append("plan") or '{"summary": "s", "scope": {}, "drafts": []}'}
        items = [{"id": "i1", "type": "requirement", "text": "Login with Google", "evidence": "login with google",
                  "candidate_keys": ["SYNT-1"], "candidate_earlier": []}]
        with mock.patch.object(ma, "find_candidates", lambda *a, **k: {"SYNT-1": {"key": "SYNT-1", "summary": "Login",
                                                                                   "status": "To Do", "type": "Story",
                                                                                   "assignee": None, "description": ""}}), \
                mock.patch.object(ma, "project_tags", lambda *a: []):
            analysis, _ = ma.analyze(items, "A: login with google", None, "SYNT", "s1", models)
        # the plan gave no draft for the new requirement, so it is asked once more for that item only
        self.assertEqual(seen, ["compare", "plan", "plan"])
        self.assertEqual(analysis["drafts"], [])

    def test_a_draft_the_plan_left_out_is_asked_for_again(self):
        import json
        from syntrace_ai.meetings import meeting_agent as ma
        prompts = []
        draft = {"for": "I1", "title": "Add Google login", "description": "d", "acceptance": ["works"],
                 "subtasks": [{"title": "API"}, {"title": "UI"}]}
        replies = iter(['{"summary": "s", "scope": {}, "drafts": []}', json.dumps({"drafts": [draft]})])

        def plan_model(p):
            prompts.append(p)
            return next(replies)
        items = [{"id": "i1", "type": "requirement", "text": "Login with Google", "relation": "new",
                  "candidate_keys": [], "candidate_earlier": []}]
        with mock.patch.object(ma, "project_tags", lambda *a: []), mock.patch.object(ma, "tag_owners", lambda *a: {}):
            result = ma.plan(items, None, "SYNT", {}, plan_model)
        self.assertEqual(len(prompts), 2)
        self.assertEqual([d["title"] for d in result["drafts"]], ["Add Google login"])


if __name__ == "__main__":
    unittest.main()


class BusyTests(FreshLLM):
    def test_gemini_503_waits_and_succeeds_on_retry(self):
        busy, ok = mock.Mock(status_code=503), mock.Mock(status_code=200)
        ok.json.return_value = {"choices": [{"message": {"content": "done"}}]}
        env = {"MEETING_EXTRACT_PROVIDER": "gemini", "GEMINI_API_KEY": "k", "GEMINI_MODEL": "g",
               "GEMINI_FALLBACK_MODEL": ""}
        with mock.patch.dict(os.environ, env), mock.patch("requests.post", side_effect=[busy, busy, ok]) as post:
            os.environ.pop("MEETING_EXTRACT_MODEL", None)
            self.assertEqual(lc.complete("extract", "p", attempts=3, wait=0), "done")
        self.assertEqual(post.call_count, 3)


def _reply(text=None, status=200, body=None):
    response = mock.Mock(status_code=status)
    response.json.return_value = body if body is not None else {"choices": [{"message": {"content": text}}]}
    return response


class FreeTierTests(FreshLLM):
    """ERNIE on OpenRouter: 50 free requests a day and 429 when crowded."""
    ENV = {"MEETING_PLAN_PROVIDER": "openrouter", "OPENROUTER_API_KEY": "o", "OPENROUTER_MODEL": "ernie",
           "OPENROUTER_FALLBACK_MODEL": "", "GEMINI_API_KEY": "g", "GEMINI_MODEL": "gem", "GEMINI_FALLBACK_MODEL": "",
           "GROQ_API_KEY": "", "MEETING_LONG_CONTEXT_CHAIN": "openrouter,gemini", "MEETING_LLM_CACHE_DIR": ""}

    def test_the_daily_limit_message_is_read(self):
        body = {"error": {"message": "Rate limit exceeded: free-models-per-day. Add 10 credits",
                          "metadata": {"headers": {"X-RateLimit-Reset": "1795478400000"}}}}
        self.assertEqual(lc._daily_limit_error(body), 1795478400.0)
        self.assertIsNone(lc._daily_limit_error({"error": {"message": "Provider returned error"}}))

    def test_a_busy_provider_moves_on_to_the_next_and_is_then_skipped(self):
        with mock.patch.dict(os.environ, self.ENV), mock.patch("requests.post", side_effect=[
                _reply(status=429), _reply(status=429), _reply(status=429), _reply("from gemini"),
                _reply("again gemini")]) as post:
            self.assertEqual(lc.complete("plan", "p", wait=0), "from gemini")
            self.assertTrue(lc.busy("openrouter"))
            self.assertEqual(lc.complete("plan", "q", wait=0), "again gemini")   # no wait on ERNIE now
        self.assertEqual([c.kwargs["json"]["model"] for c in post.call_args_list],
                         ["ernie", "ernie", "ernie", "gem", "gem"])

    def test_a_used_up_daily_limit_skips_until_the_reset_without_waiting(self):
        daily = _reply(status=429, body={"error": {"message": "Rate limit exceeded: free-models-per-day"}})
        with mock.patch.dict(os.environ, self.ENV), mock.patch("requests.post", side_effect=[daily, _reply("gem")]) as post:
            self.assertEqual(lc.complete("plan", "p", wait=0), "gem")
        self.assertEqual(post.call_count, 2)   # one try, no backoff on a daily limit
        self.assertGreater(lc._BUSY["openrouter"], time.time() + 60)

    def test_the_last_requests_of_the_day_stay_for_urgent_calls(self):
        env = dict(self.ENV, OPENROUTER_DAILY_LIMIT="10", MEETING_URGENT_RESERVE="2", GEMINI_API_KEY="")
        lc._USED[("openrouter", lc._day())] = 8
        with mock.patch.dict(os.environ, env), mock.patch("requests.post", return_value=_reply("ok")):
            self.assertFalse(lc.has_budget("openrouter"))
            self.assertTrue(lc.has_budget("openrouter", urgent=True))
            self.assertEqual(lc.complete("plan", "p", wait=0, urgent=True), "ok")
            self.assertEqual(lc.used_today("openrouter"), 9)

    def test_a_cached_reply_is_reused_for_the_same_prompt_only(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            env = dict(self.ENV, MEETING_LLM_CACHE_DIR=folder)
            with mock.patch.dict(os.environ, env), mock.patch("requests.post", return_value=_reply('{"a": 1}')) as post:
                self.assertEqual(lc.complete("plan", "p", wait=0), '{"a": 1}')
                self.assertEqual(lc.complete("plan", "p", wait=0), '{"a": 1}')
                self.assertEqual(post.call_count, 1)
                lc.complete("plan", "another prompt", wait=0)
                self.assertEqual(post.call_count, 2)
                lc.complete("plan", "p", temperature=0.5, wait=0)   # not cached away from temperature 0
                self.assertEqual(post.call_count, 3)

    def test_a_cut_off_reply_is_not_kept(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            env = dict(self.ENV, MEETING_LLM_CACHE_DIR=folder)
            with mock.patch.dict(os.environ, env), mock.patch("requests.post", return_value=_reply('{"items": [{"a"')) as post:
                lc.complete("plan", "p", wait=0)
                lc.complete("plan", "p", wait=0)
            self.assertEqual(post.call_count, 2)


class ConnectionDropTests(unittest.TestCase):
    """A dropped connection to OpenRouter is waited out like a busy moment, not a failed provider."""

    def test_a_connection_error_is_a_wait(self):
        import requests
        with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": "k"}), \
                mock.patch.object(requests, "post", side_effect=requests.exceptions.ConnectionError("reset")):
            with self.assertRaises(lc.RateLimited) as caught:
                lc._openai_compatible("openrouter", "u", "OPENROUTER_API_KEY", 1, "m", "p", 0)
        self.assertIsNone(caught.exception.until)
        self.assertIn("connection failed", str(caught.exception))


class SeedTests(unittest.TestCase):
    """A fixed seed asks the provider for the same reply each run (MEETING_LLM_SEED)."""

    def test_the_seed_is_sent_and_can_be_turned_off(self):
        with mock.patch.dict(os.environ, {"MEETING_LLM_SEED": ""}):
            os.environ.pop("MEETING_LLM_SEED")
            self.assertEqual(lc._payload("m", "p", 0)["seed"], 7)
        with mock.patch.dict(os.environ, {"MEETING_LLM_SEED": "123"}):
            self.assertEqual(lc._payload("m", "p", 0)["seed"], 123)
        with mock.patch.dict(os.environ, {"MEETING_LLM_SEED": "none"}):
            self.assertNotIn("seed", lc._payload("m", "p", 0))
