"""Understands what a question wants by meaning (bge-m3 embeddings), before any model call.

Each intent has example sentences. A greeting or a thank-you is answered here only when its closest
example is close enough AND clearly closer than every data or general example, so "hi, what are my
open tickets?" or "الجو عامل ايه؟" still go on. Requests to change Jira are not routed here:
embeddings match what a sentence is about, not whether it asks or orders, so "مين قفل SYNT-97؟" and
"اقفل SYNT-97" look alike; the LLM planner and the agent understand that difference. Anything unsure
returns None and the LLM planner decides, so this layer can only save calls, never lose a question.
The question's vector is cached, so the ticket search reuses it instead of embedding it again.
"""
import logging
import math
import os
import re
import threading

log = logging.getLogger(__name__)

MIN_SIMILARITY = float(os.getenv("INTENT_MIN_SIMILARITY", "0.65"))
MIN_MARGIN = float(os.getenv("INTENT_MIN_MARGIN", "0.12"))
KEY_RE = re.compile(r'\b[A-Z][A-Z0-9_]*-\d+\b')

EXAMPLES = {
    "chat": [
        "hi", "hello", "hey", "good morning", "good evening", "how are you?", "hey there, how is it going?",
        "what can you do?", "who are you?", "how can you help me?", "what kind of questions can I ask?",
        "اهلا", "أهلًا", "مرحبا", "السلام عليكم", "ازيك", "عامل ايه؟", "صباح الخير", "مساء الخير",
        "hi SynTrace", "hello bot", "أهلا يا بوت", "إنت مين؟", "تقدر تعمل إيه؟", "بتعرف تعمل ايه؟", "أسألك عن إيه؟", "ازاي تقدر تساعدني؟",
    ],
    "thanks": [
        "thanks", "thank you", "thanks a lot", "thank you so much", "great, thanks", "perfect, thank you",
        "شكرا", "شكرًا جدًا", "متشكرة", "متشكر أوي", "تسلم", "تسلمي", "ميرسي", "تمام شكرا", "جزاك الله خير",
    ],
    "data": [
        "who closed SYNT-9?", "which tickets were closed last week?", "who moved SYNT-5 to Done?",
        "when was SYNT-5 moved to In Progress?", "who created SYNT-20?", "tickets created yesterday",
        "who is assigned to SYNT-3?", "what are my tickets?", "tickets assigned to Sara", "open tickets in SYNTECH",
        "what is the status of SYNT-5?", "what is the priority of SYNT-4?", "show the comments on SYNT-7",
        "how many hours were logged on SYNT-8?", "which tickets have the backend label?", "what are the subtasks of SYNT-12?",
        "which bugs are open?", "who changed the status of SYNT-5?", "who was SYNT-3 reassigned to?",
        "what was deleted from the sprint?", "summarize SYNT-4", "what is SYNT-7 about?", "what happened yesterday?",
        "مين قفل SYNT-9؟", "التذاكر اللي اتقفلت الأسبوع اللي فات", "مين حرك SYNT-5 لـ Done؟", "مين عمل SYNT-20؟",
        "التذاكر اللي اتعملت امبارح", "مين ماسك SYNT-3؟", "إيه التذاكر بتاعتي؟", "تذاكر فاطمة",
        "التذاكر المفتوحة في SYNTECH", "إيه حالة SYNT-5؟", "الـ priority بتاعة SYNT-4 إيه؟", "الكومنتات على SYNT-7",
        "كام ساعة اتسجلت على SYNT-8؟", "إيه الـ subtasks بتاعة SYNT-12؟", "مين غير الـ status بتاع SYNT-5؟",
        "SYNT-3 اتعملها assign لمين؟", "لخصلي SYNT-4", "فاطمة عملت إيه امبارح؟", "مين عنده أكتر تذاكر مفتوحة؟",
        "اكتب email لمديري عن التذاكر المفتوحة", "اكتبلي status update عن الـ sprint",
        "close SYNT-9", "move SYNT-5 to Done", "assign SYNT-3 to me", "حرك SYNT-5 لـ Done", "اقفل SYNT-9",
    ],
    "general": [
        "الجو عامل ايه النهاردة؟", "الجو حر؟", "what's the weather like?", "يعني إيه story points؟",
        "what is a sprint retrospective?", "اشرحلي REST API", "explain Scrum in two lines",
        "اكتبلي email أطلب فيه تأجيل الـ deadline", "translate this to English", "ازاي أعمل subtask في Jira؟",
        "إيه أخبار الكورة؟", "what time is it?", "النهاردة كام في الشهر؟", "احكيلي نكتة", "tell me a joke",
    ],
}
ROUTED = ("chat", "thanks")   # actions are left to the LLM: embeddings match the topic, not the intent

_vectors = None
_lock = threading.Lock()


def _normalize(v):
    n = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / n for x in v]


def _example_vectors():
    global _vectors
    with _lock:
        if _vectors is None:
            from syntrace_ai.graph.embeddings import embed_texts
            texts = [(label, t) for label, items in EXAMPLES.items() for t in items]
            vecs = embed_texts([t for _, t in texts])
            _vectors = [(label, t, _normalize(v)) for (label, t), v in zip(texts, vecs)]
        return _vectors


def _shape(question):
    """Ticket keys become one placeholder key, so "close ABC-7" is as close to "close SYNT-9" as possible."""
    return KEY_RE.sub("SYNT-1", " ".join(question.split()))


def scores(question):
    """-> {intent: best similarity} plus the closest example of each, for calibration."""
    from syntrace_ai.graph.semantic_search import _query_vector
    q = _normalize(_query_vector(_shape(question)))
    best = {}
    for label, text, v in _example_vectors():
        s = sum(a * b for a, b in zip(q, v))
        if label not in best or s > best[label][0]:
            best[label] = (s, text)
    return best


def route(question):
    """"chat" | "thanks" | None (unsure, or anything else: the planner decides)."""
    if not question or len(question) > 200:
        return None
    try:
        best = scores(question)
    except Exception as e:   # Ollama down: the planner still understands the question
        log.warning("intent routing unavailable: %s", type(e).__name__)
        return None
    label, (score, _) = max(best.items(), key=lambda kv: kv[1][0])
    if label not in ROUTED or score < MIN_SIMILARITY:
        return None
    others = max(v[0] for k, v in best.items() if k not in ROUTED)
    if score - others < MIN_MARGIN:
        return None
    return label
