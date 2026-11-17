"""
conversation.py
Short memory of each user's last questions, so a follow-up such as "and its subtasks?" is
answered about the ticket the user just asked about.

Before the normal pipeline runs, a follow-up is rewritten into a question that stands on its own
("What are the subtasks of SYNTECH-1?"). The rest of the service is unchanged, and a question that
already stands on its own is passed through as it is.

The memory is kept in this process only, per company, user and chat, for CONVERSATION_SECONDS.
It is lost on restart, which is fine for a chat. Question text is never logged.
"""
import logging
import os
import re
import threading
import time
from collections import deque

import answer_generator as ag

log = logging.getLogger(__name__)

MAX_TURNS = int(os.getenv("CONVERSATION_TURNS", "3"))
TTL_SECONDS = int(os.getenv("CONVERSATION_SECONDS", "1800"))
MAX_USERS = 2000
ANSWER_CHARS = 400
MAX_REWRITE_CHARS = 600

_lock = threading.Lock()
_memory = {}   # (company, user, chat) -> deque of (time, question, answer, keys)

REWRITE = """You turn a follow-up question from a chat about Jira tickets into one that stands on its own.
Earlier in this chat (oldest first):
{history}

Follow-up question: {question}

Rules:
- If the follow-up already stands on its own, return it unchanged.
- Otherwise replace words such as "it", "its", "this ticket", "them", "the same", "بتاعتها", "دي", "ده",
  "هو", "هي" with the ticket keys, people or sprints they refer to in the earlier questions and answers.
- Keep the language and wording of the follow-up. Copy ticket keys and names exactly.
- Do not answer the question and do not add anything it does not ask.
Return only the rewritten question."""


def _key(company, user, chat):
    return (company, user, chat or "")


def recent(company, user, chat=None):
    now = time.monotonic()
    with _lock:
        turns = _memory.get(_key(company, user, chat))
        if not turns:
            return []
        return [t for t in turns if now - t[0] < TTL_SECONDS]


def remember(company, user, chat, question, answer, links):
    keys = [link["key"] if isinstance(link, dict) else getattr(link, "key", None) for link in links or []]
    keys = [k for k in keys if k][:5]
    with _lock:
        if len(_memory) >= MAX_USERS and _key(company, user, chat) not in _memory:
            _memory.pop(next(iter(_memory)))
        turns = _memory.setdefault(_key(company, user, chat), deque(maxlen=MAX_TURNS))
        turns.append((time.monotonic(), question, (answer or "")[:ANSWER_CHARS], keys))


MERGE = """A user sent several messages one after another before getting an answer. Turn them into one
question that stands on its own.
{history}Messages, in the order sent:
{messages}

Rules:
- A later message that corrects an earlier one wins, for example "I meant SYNDATA-1" replaces the
  ticket asked about.
- A later message that asks something more is added, for example "and who is assigned?" after a
  question about SYNTECH-1 becomes "What is the status of SYNTECH-1 and who is assigned to it?".
- Replace words such as "it", "its", "بتاعتها", "دي" with what they refer to.
- Keep the language of the messages. Copy ticket keys and names exactly.
- Do not answer and do not add anything the messages do not ask.
Return only the question."""


def merge(messages, turns, complete=None):
    """Messages sent before an answer came back, as one question. Without the model, they are
    joined, which the planner can still split into parts."""
    messages = [m.strip() for m in messages if m and m.strip()]
    if len(messages) <= 1:
        return standalone(messages[0] if messages else "", turns, complete)
    history = "".join(f"Earlier in this chat (oldest first):\n" +
                      "\n".join(f"Q: {q}\nA: {a}" for _, q, a, _ in turns) + "\n\n" if turns else "")
    joined = "\n".join(f"{n}. {m}" for n, m in enumerate(messages, 1))
    fallback = " ".join(m if m.endswith(("?", "؟", ".")) else m + ("؟" if has_arabic(m) else "?") for m in messages)
    try:
        merged = (complete or ag._complete)(MERGE.format(history=history, messages=joined))
    except Exception as error:
        log.warning("message merge failed: %s", type(error).__name__)
        merged = None
    merged = re.sub(r"\s+", " ", (merged or "")).strip().strip('"')
    if not merged or len(merged) > MAX_REWRITE_CHARS * 2:
        return fallback
    known = set()
    for m in messages:
        known |= set(ag.KEY_RE.findall(m.upper()))
    for _, q, a, keys in turns:
        known |= set(keys) | set(ag.KEY_RE.findall(q.upper())) | set(ag.KEY_RE.findall(a.upper()))
    if not set(ag.KEY_RE.findall(merged.upper())) <= known:
        return fallback
    return merged


def has_arabic(text):
    return bool(re.search("[\u0600-\u06FF]", text or ""))


def drop_last(company, user, chat, count):
    """The user edited a question: forget it and every turn after it."""
    if count <= 0:
        return
    with _lock:
        turns = _memory.get(_key(company, user, chat))
        for _ in range(min(count, len(turns or []))):
            turns.pop()


def from_history(pairs):
    """The backend's (question, answer) pairs, oldest first, as turns. Only the last MAX_TURNS count."""
    turns = []
    for question, answer in list(pairs)[-MAX_TURNS:]:
        keys = list(dict.fromkeys(ag.KEY_RE.findall(f"{question} {answer}".upper())))[:5]
        turns.append((time.monotonic(), question or "", (answer or "")[:ANSWER_CHARS], keys))
    return turns


def forget(company, user, chat=None):
    with _lock:
        _memory.pop(_key(company, user, chat), None)


def _fallback(question, turns):
    """Without the model: a short question with no ticket key is about the last tickets named."""
    if ag.KEY_RE.search(question.upper()) or len(question.split()) > 12:
        return question
    keys = turns[-1][3] or ag.KEY_RE.findall(turns[-1][1].upper())
    return f"{question} ({', '.join(dict.fromkeys(keys))})" if keys else question


def standalone(question, turns, complete=None):
    """The question to answer: the follow-up rewritten with what it refers to, or the question itself."""
    # A question that names a ticket already says what it is about, and needs no model call.
    if not turns or ag.KEY_RE.search(question.upper()):
        return question
    import intent
    if intent.route(question) in ("chat", "thanks"):   # "شكرا" after a ticket question stays a thank-you
        return question
    history = "\n".join(f"Q: {q}\nA: {a}" for _, q, a, _ in turns)
    try:
        rewritten = (complete or ag._complete)(REWRITE.format(history=history, question=question))
    except Exception as error:
        log.warning("follow-up rewrite failed: %s", type(error).__name__)
        rewritten = None
    rewritten = re.sub(r"\s+", " ", (rewritten or "")).strip().strip('"')
    if not rewritten or len(rewritten) > MAX_REWRITE_CHARS:
        return _fallback(question, turns)
    # The model must not invent tickets: every key it writes was in the chat or the question.
    known = set(ag.KEY_RE.findall(question.upper()))
    for _, q, a, keys in turns:
        known |= set(keys) | set(ag.KEY_RE.findall(q.upper())) | set(ag.KEY_RE.findall(a.upper()))
    if not set(ag.KEY_RE.findall(rewritten.upper())) <= known:
        return _fallback(question, turns)
    return rewritten
