"""
llm_client.py
One way to call a language model, with the provider and model chosen per step from config, so a step
can move between Groq and Gemini without code changes.

  MEETING_<STEP>_PROVIDER   groq (default), gemini, openrouter or ollama (local: nothing leaves the machine)
  MEETING_<STEP>_MODEL      the model name; default GROQ_MODEL, GEMINI_MODEL, OPENROUTER_MODEL or OLLAMA_CHAT_MODEL
  steps: extract (items from a transcript part), write (each requirement as a user story), compare,
         plan, session (live meeting help)

Any failure tries the step's fallback (GROQ_FALLBACK_MODEL on Groq); a rate limit waits and tries
again, so a long transcript can finish in the background. Replies are plain text.

Free long-context models are shared and busy (ERNIE on OpenRouter: 50 requests a day, 429 when crowded):
  - a provider that stays busy is skipped for a while (MEETING_BUSY_COOLDOWN_SECONDS; its daily limit:
    until the next day) instead of being waited on by every meeting;
  - the next long-context provider with a key is tried (MEETING_LONG_CONTEXT_CHAIN, default
    openrouter), then Groq (short steps) or Groq in parts (extraction, in meeting_notes);
  - OPENROUTER_FALLBACK_API_KEY (another account) takes over when the main key's daily limit is used up;
  - requests are counted per day (OPENROUTER_DAILY_LIMIT, GEMINI_DAILY_LIMIT); the last
    MEETING_URGENT_RESERVE are kept for urgent calls (the live wrap-up, while the client is still there);
  - with MEETING_LLM_CACHE_DIR set, a reply at temperature 0 is reused for the same provider, model
    and prompt for MEETING_LLM_CACHE_HOURS (the same transcript sent again, the lab running again).
"""
import hashlib
import json
import logging
import os
import time

log = logging.getLogger("syntrace.llm")

STEPS = ("extract", "write", "compare", "plan", "session", "select", "classify")
PROVIDERS = ("groq", "gemini", "openrouter", "ollama")
LONG_CONTEXT = ("gemini", "openrouter")   # can read a whole meeting transcript in one request
GEMINI_URL = os.getenv("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
GEMINI_TIMEOUT = float(os.getenv("GEMINI_TIMEOUT_SECONDS", "120"))
OPENROUTER_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1/chat/completions")
OPENROUTER_TIMEOUT = float(os.getenv("OPENROUTER_TIMEOUT_SECONDS", "180"))
# Ollama, the same server as the embeddings: a local model reads the meeting in parts (a small GPU)
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
OLLAMA_TIMEOUT = float(os.getenv("OLLAMA_TIMEOUT_SECONDS", "600"))
OLLAMA_CONTEXT = int(os.getenv("OLLAMA_NUM_CTX", "8192"))   # Ollama's default is small and cuts silently
# Each long-context provider: its key, default model, and fallback model settings.
_LONG = {"gemini": ("GEMINI_API_KEY", "GEMINI_MODEL", "gemini-flash-latest", "GEMINI_FALLBACK_MODEL"),
         "openrouter": ("OPENROUTER_API_KEY", "OPENROUTER_MODEL", "baidu/ernie-5.5-flash-preview:free",
                        "OPENROUTER_FALLBACK_MODEL")}


class LLMUnavailable(Exception):
    def __init__(self, message, rate_limited=False):
        super().__init__(message)
        self.rate_limited = rate_limited


class ProviderError(Exception):
    """A provider refused the call (model not found, bad request...); the message holds no secret."""


class RateLimited(Exception):
    """A provider said: too many requests or tokens for now. `until` (epoch seconds) when it said how
    long: its daily limit is used up."""

    def __init__(self, message, until=None):
        super().__init__(message)
        self.until = until


def _next_day():
    now = time.time()
    return now - now % 86400 + 86400   # the next midnight UTC, when free daily limits reset


def _daily_limit_error(body):
    """-> epoch seconds when a 429 is a used-up daily limit (OpenRouter: "free-models-per-day"), else None."""
    error = (body or {}).get("error") or {}
    message = str(error.get("message") or "").lower()
    if "per-day" not in message and "per day" not in message:
        return None
    reset = ((error.get("metadata") or {}).get("headers") or {}).get("X-RateLimit-Reset")
    try:
        return float(reset) / 1000
    except (TypeError, ValueError):
        return _next_day()


_WARNED = set()


def settings(step, provider=None):
    """-> (provider, [models]) for a step, from the environment at call time. `provider` overrides the
    configured one (a fallback); the step's own model setting then applies only to its own provider."""
    if step not in STEPS:
        raise ValueError(f"unknown model step: {step}")
    configured = (os.getenv(f"MEETING_{step.upper()}_PROVIDER") or "groq").strip().lower()
    provider = (provider or configured).strip().lower()
    if provider not in PROVIDERS:
        raise ValueError(f"unknown model provider for {step}: {provider}")
    model = os.getenv(f"MEETING_{step.upper()}_MODEL") if provider == configured else None
    if provider in _LONG and not os.getenv(_LONG[provider][0]):
        # a deployment without the key still works, on Groq (the transcript is then read in parts)
        if (step, provider) not in _WARNED:
            _WARNED.add((step, provider))
            log.warning("%s is set to %s but %s is empty: using groq", step, provider, _LONG[provider][0])
        provider, model = "groq", None
    if provider == "ollama":
        return provider, [model or os.getenv("OLLAMA_CHAT_MODEL", "qwen2.5:7b")]
    if provider in _LONG:
        _, model_env, default, fallback_env = _LONG[provider]
        models = [model or os.getenv(model_env, default)]
        fallback = os.getenv(fallback_env)
    else:
        from syntrace_ai.assistant import answer_generator as ag
        # the helper that picks tool results is a small fast model, with its own Groq limits
        default = os.getenv("SELECT_MODEL", "llama-3.1-8b-instant") if step == "select" else ag.GROQ_MODEL
        models = [model or default]
        fallback = None if step == "select" else ag.fallback_model(models[0])
        if step != "select" and ag.routes(models[0]) == [fallback]:
            models = []   # the main account's day is used up: straight to the fallback account
    if fallback and fallback not in models:
        models.append(fallback)
    return provider, models


def _groq(model, prompt, temperature):
    from syntrace_ai.assistant import answer_generator as ag
    route = model
    client, model = ag.client_for(model)
    try:
        seed = {k: v for k, v in _payload(model, prompt, temperature).items() if k == "seed"}
        completion = client.chat.completions.create(
            model=model, messages=[{"role": "user", "content": prompt}], temperature=temperature, **seed)
    except Exception as exc:
        if type(exc).__name__ == "RateLimitError":
            ag.note_limit(exc, route)
            raise RateLimited(str(exc)) from None
        raise
    ag.count_tokens(completion, "meeting")
    return completion.choices[0].message.content or ""


def _payload(model, prompt, temperature):
    """The chat request. A fixed seed (MEETING_LLM_SEED, default 7; empty for none) asks the provider for
    the same reply to the same prompt: at temperature 0 a shared free model still varies run to run."""
    body = {"model": model, "temperature": temperature, "messages": [{"role": "user", "content": prompt}]}
    seed = os.getenv("MEETING_LLM_SEED", "7").strip()
    if seed.isdigit():
        body["seed"] = int(seed)
    return body


def _openai_compatible(name, url, key_env, timeout, model, prompt, temperature, headers=None):
    """A provider's OpenAI-compatible chat endpoint, with requests (no extra package)."""
    import requests
    key = os.getenv(key_env)
    if not key:
        raise LLMUnavailable(f"{key_env} is not set")
    try:
        response = requests.post(url, timeout=timeout,
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                                          **(headers or {})},
                                 json=_payload(model, prompt, temperature))
    except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as exc:
        # the network dropped for a moment: wait and try again, do not leave the long-context model for
        # the whole meeting (a ConnectionError sent team_meeting_1 to Groq in parts)
        raise RateLimited(f"{name} connection failed (busy): {type(exc).__name__}") from None
    if response.status_code == 429:
        try:
            until = _daily_limit_error(response.json())
        except ValueError:
            until = None
        raise RateLimited(f"{name} daily limit used up" if until else f"{name} rate limit", until)
    if response.status_code in (500, 502, 503, 504):   # overloaded for a moment: wait and try again
        raise RateLimited(f"{model} -> HTTP {response.status_code} (busy)")
    if response.status_code != 200:
        raise ProviderError(f"{model} -> HTTP {response.status_code}")
    body = response.json() or {}
    if body.get("error"):   # OpenRouter can answer 200 with the provider's error inside
        until = _daily_limit_error(body)
        raise RateLimited(f"{name} daily limit used up" if until else f"{model} -> provider error (busy)", until)
    choices = body.get("choices") or []
    return ((choices[0].get("message") or {}).get("content") or "") if choices else ""


def _gemini(model, prompt, temperature):
    return _openai_compatible("gemini", GEMINI_URL, "GEMINI_API_KEY", GEMINI_TIMEOUT, model, prompt, temperature)


OPENROUTER_KEYS = ("OPENROUTER_API_KEY", "OPENROUTER_FALLBACK_API_KEY")
_USED_UP_KEYS = {}   # key env name -> epoch seconds until which its daily limit is used up


def _openrouter_keys():
    """The OpenRouter keys set, in order: the main key, then OPENROUTER_FALLBACK_API_KEY when set."""
    return [name for name in OPENROUTER_KEYS if os.getenv(name)] or [OPENROUTER_KEYS[0]]


def _openrouter(model, prompt, temperature):
    """ERNIE on the main key; when its daily limit is used up, the same model on the fallback key (another
    account), like GROQ_FALLBACK_API_KEY. Only a used-up daily limit moves to the next key."""
    keys = _openrouter_keys()
    now = time.time()
    for n, key_env in enumerate(keys):
        if _USED_UP_KEYS.get(key_env, 0) > now:
            continue
        try:
            # the title shows in the OpenRouter dashboard; it carries no data
            return _openai_compatible("openrouter", OPENROUTER_URL, key_env, OPENROUTER_TIMEOUT,
                                      model, prompt, temperature, headers={"X-Title": "SynTrace"})
        except RateLimited as exc:
            if not exc.until:
                raise
            _USED_UP_KEYS[key_env] = exc.until
            if n == len(keys) - 1:
                raise
            log.warning("openrouter: %s used up for today, moving to %s", key_env, keys[n + 1])
    raise RateLimited("openrouter daily limit used up", max(_USED_UP_KEYS.values(), default=now + 3600))


def _ollama(model, prompt, temperature):
    """Ollama's own chat API: unlike its OpenAI-compatible one, it takes the context size."""
    import requests
    try:
        response = requests.post(f"{OLLAMA_URL.rstrip('/')}/api/chat", timeout=OLLAMA_TIMEOUT,
                                 json={"model": model, "stream": False,
                                       "messages": [{"role": "user", "content": prompt}],
                                       "options": {"temperature": temperature, "num_ctx": OLLAMA_CONTEXT}})
    except requests.ConnectionError:
        raise ProviderError("ollama is not reachable") from None
    if response.status_code == 503:
        raise RateLimited("ollama is busy")
    if response.status_code != 200:
        raise ProviderError(f"{model} -> HTTP {response.status_code}")
    return ((response.json() or {}).get("message") or {}).get("content") or ""


CALLS = {"groq": _groq, "gemini": _gemini, "openrouter": _openrouter, "ollama": _ollama}


MAX_WAIT = float(os.getenv("MEETING_RATE_LIMIT_MAX_WAIT_SECONDS", "120"))


def backoff(wait, attempt):
    """Seconds before the next try: doubling from `wait` (20, 40, 80...) up to MAX_WAIT, with a little
    random spread so several waiting meetings do not all knock at the same second."""
    import random
    if wait <= 0:
        return 0
    return min(MAX_WAIT, wait * (2 ** attempt)) * random.uniform(0.85, 1.15)


# ---------- busy providers, daily budget, reply cache ----------

COOLDOWN = float(os.getenv("MEETING_BUSY_COOLDOWN_SECONDS", "300"))
SWITCH_ATTEMPTS = int(os.getenv("MEETING_SWITCH_ATTEMPTS", "3"))   # tries before moving to the next provider
_BUSY = {}    # provider -> epoch seconds until which it is skipped
_USED = {}    # (provider, UTC day) -> requests sent


def busy(provider):
    return _BUSY.get(provider, 0) > time.time()


def _cool(provider, until=None):
    _BUSY[provider] = max(_BUSY.get(provider, 0), until or time.time() + COOLDOWN)
    log.warning("%s is busy: skipped for %d s", provider, _BUSY[provider] - time.time())


def _daily_limit(provider):
    # ERNIE's free 50 a day is per key: a fallback key doubles the day's budget
    default = str(50 * len(_openrouter_keys())) if provider == "openrouter" else "0"
    return int(os.getenv(f"{provider.upper()}_DAILY_LIMIT", default) or 0)


def _day():
    return time.strftime("%Y-%m-%d", time.gmtime())


def used_today(provider):
    return _USED.get((provider, _day()), 0)


def has_budget(provider, urgent=False):
    """False once today's requests reach the provider's daily limit; normal calls stop earlier, so the
    last few stay for urgent ones."""
    limit = _daily_limit(provider)
    if not limit:
        return True
    reserve = 0 if urgent else int(os.getenv("MEETING_URGENT_RESERVE", "5"))
    return used_today(provider) < max(0, limit - reserve)


def _spend(provider):
    key = (provider, _day())
    _USED[key] = _USED.get(key, 0) + 1


def _cache_path(provider, model, step, prompt, temperature):
    folder = os.getenv("MEETING_LLM_CACHE_DIR")
    if not folder or temperature != 0 or os.getenv("MEETING_LLM_CACHE") == "0":
        return None
    key = hashlib.sha256(json.dumps([provider, model, step, prompt], ensure_ascii=False).encode()).hexdigest()
    return os.path.join(folder, key[:2], key + ".txt")


def _cache_get(path):
    try:
        if path and time.time() - os.path.getmtime(path) < float(os.getenv("MEETING_LLM_CACHE_HOURS", "24")) * 3600:
            with open(path, encoding="utf-8") as f:
                return f.read()
    except OSError:
        pass
    return None


def _whole_json(reply):
    """Every step answers one JSON object: a reply cut off or broken is not kept for next time."""
    reply = (reply or "").rsplit("</think>", 1)[-1]
    start, end = reply.find("{"), reply.rfind("}")
    if start < 0 or end < start:
        return False
    try:
        json.loads(reply[start:end + 1])
        return True
    except ValueError:
        return False


def _cache_put(path, reply):
    if not path or not reply or not _whole_json(reply):
        return
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(reply)
    except OSError as exc:
        log.warning("reply cache write failed: %s", type(exc).__name__)


def _long_chain(first):
    """The long-context providers to try, `first` first, then MEETING_LONG_CONTEXT_CHAIN, each with a key."""
    # Gemini (Flash-Lite) was taken out of the default: in the lab it returned far fewer items than ERNIE
    # (ES2004b: 4-8 against 44); MEETING_LONG_CONTEXT_CHAIN=openrouter,gemini puts it back
    order = [p.strip() for p in os.getenv("MEETING_LONG_CONTEXT_CHAIN", "openrouter").split(",") if p.strip()]
    chain = [first] + [p for p in order if p in _LONG and p != first]
    return [p for p in chain if os.getenv(_LONG[p][0])]


class _Exhausted(Exception):
    def __init__(self, rate_limited, until=None):
        super().__init__("exhausted")
        self.rate_limited, self.until = rate_limited, until


# (step, provider, model or "cache") of every reply, in order: the lab reads which provider really
# answered, so a run on a fallback is never taken for the main model's result
ANSWERED_BY = []


def _try(step, provider, models, prompt, temperature, attempts, wait):
    """One provider's models, waiting on its rate limits; raises _Exhausted."""
    from syntrace_ai.assistant import answer_generator as ag
    call = CALLS[provider]
    rate_limited, until = False, None
    for attempt in range(attempts):
        rate_limited = False
        for model in models:
            if provider == "groq" and len(models) > 1 and ag.main_resting(model):
                continue   # its day is used up: the fallback account in this list answers
            path = _cache_path(provider, model, step, prompt, temperature)
            cached = _cache_get(path)
            if cached is not None:
                ANSWERED_BY.append((step, provider, "cache"))
                return cached
            try:
                reply = call(model, prompt, temperature).translate(ag._TYPOGRAPHY)
                ANSWERED_BY.append((step, provider, model))
                _spend(provider)
                _BUSY.pop(provider, None)
                _cache_put(path, reply)
                return reply
            except RateLimited as exc:
                log.warning("%s call must wait (%s): %s", step, provider, exc)
                rate_limited = True
                if exc.until:   # the daily limit is used up: no point waiting today
                    raise _Exhausted(True, exc.until) from None
            except LLMUnavailable:
                raise
            except ProviderError as exc:
                _spend(provider)
                log.warning("%s call failed (%s): %s", step, provider, exc)
            except Exception as exc:
                log.warning("%s call failed (%s): %s", step, provider, type(exc).__name__)
        if not rate_limited:
            break
        if attempt < attempts - 1:
            time.sleep(backoff(wait, attempt))
    raise _Exhausted(rate_limited, until)


def complete(step, prompt, temperature=0, attempts=None, wait=None, provider=None, urgent=False):
    """The model's reply for one step. Raises LLMUnavailable when every model failed. `urgent` may use
    the daily requests kept in reserve (the live wrap-up)."""
    attempts = attempts or int(os.getenv("MEETING_LLM_ATTEMPTS", "6"))
    wait = int(os.getenv("MEETING_RATE_LIMIT_WAIT_SECONDS", "20")) if wait is None else wait
    first, models = settings(step, provider)
    groq_after = step != "extract" and bool(os.getenv("GROQ_API_KEY"))   # extraction falls back in parts itself
    if first not in _LONG:
        chain = [first]
    else:
        chain = [p for p in _long_chain(first) if not busy(p) and has_budget(p, urgent)]
        if not chain and not groq_after and not os.getenv("GROQ_API_KEY"):
            chain = [first]   # nothing else to go to: wait on it
        for skipped in [p for p in _long_chain(first) if p not in chain]:
            log.warning("%s: %s skipped (%s)", step, skipped, "busy" if busy(skipped) else "daily limit reached")
    rate_limited = False
    for n, p in enumerate(chain):
        last = n == len(chain) - 1 and not groq_after and step != "extract"
        tries = attempts if (last or p not in _LONG) else min(attempts, SWITCH_ATTEMPTS)
        try:
            return _try(step, p, models if p == first else settings(step, p)[1], prompt, temperature, tries, wait)
        except _Exhausted as exc:
            rate_limited = rate_limited or exc.rate_limited
            if p in _LONG and exc.rate_limited:
                _cool(p, exc.until)
    if first in _LONG and groq_after:
        # a short step (compare, plan, write, session) fits Groq: finish there instead of losing the step.
        # Extraction falls back on its own, in parts (meeting_notes.extract_items).
        log.warning("%s: long-context providers unavailable, using groq", step)
        return complete(step, prompt, temperature, attempts, wait, provider="groq")
    raise LLMUnavailable(f"{step} is rate limited; try again later" if rate_limited else f"{step} is unavailable",
                         rate_limited=rate_limited)


def for_step(step, urgent=False):
    """A one-argument callable (prompt -> reply) for code that takes an llm function."""
    settings(step)   # fail early on a bad config
    return lambda prompt: complete(step, prompt, urgent=urgent)
