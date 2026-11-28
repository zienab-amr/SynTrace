"""
meetings/writer.py
The second step after extraction: each requirement the client asked for is written properly, from what
was said around it.

  user_story         "As a <role>, I want <goal>[, so that <benefit>]." (the benefit only when it was said)
  category           functional | non_functional
  clarity            clear | unclear, with one question to ask the client when unclear
  priority           high | medium | low, only when a speaker said how important or urgent it is,
                     with the words they used (checked against the transcript)
  acceptance_said    conditions the client stated, each with its exact words (checked)
  acceptance_suggested
                     testable criteria the AI proposes; kept apart from what the client said, so the
                     review screen can show them as suggestions to confirm

The step runs on the configured "write" model (GPT-OSS by default): it reads only the requirement and the
lines around its evidence, so it needs no long context. It never fails the meeting: on any error the
items keep what extraction gave them.
"""
import json
import re
import logging

from syntrace_ai.meetings import text as mn
from syntrace_ai.meetings.prompts import WRITE_PROMPT

log = logging.getLogger("syntrace.meetings.writer")

CATEGORIES = ("functional", "non_functional")
CLARITY = ("clear", "unclear")
PRIORITIES = ("high", "medium", "low")
CONTEXT_LINES = 3          # lines before and after the evidence the model sees
BATCH = 4                  # requirements per call (Groq: about 8K tokens per request, reasoning included)
MAX_SAID = 6
MAX_SUGGESTED = 4

def _context(evidence, text, lines):
    """The lines around the evidence, numbered, so the model sees who asked and why."""
    all_lines = (text or "").split("\n")
    if not lines:
        return ""
    first, last = max(1, min(lines) - CONTEXT_LINES), min(len(all_lines), max(lines) + CONTEXT_LINES)
    return "\n".join(f"{n}: {all_lines[n - 1]}" for n in range(first, last + 1))


def _block(n, item, text):
    return (f"Requirement id {n}: {item['text']}\nClient's words: {item['evidence']}\n"
            f"Context:\n{_context(item['evidence'], text, item.get('lines'))}\n")


def _parse(reply):
    reply = (reply or "").rsplit("</think>", 1)[-1]
    start, end = reply.find("{"), reply.rfind("}")
    if start < 0 or end < start:
        return []
    try:
        data = json.loads(reply[start:end + 1])
    except ValueError:
        return _complete_rows(reply)
    rows = data.get("requirements") if isinstance(data, dict) else None
    return [r for r in rows if isinstance(r, dict)] if isinstance(rows, list) else []


def _complete_rows(reply):
    """The whole rows of a reply cut off in the middle (the model ran out of tokens): the rows before
    the cut are good; the rest is asked again."""
    at = reply.find("[", reply.find('"requirements"'))
    if reply.find('"requirements"') < 0 or at < 0:
        return []
    decoder, rows, at = json.JSONDecoder(), [], at + 1
    while True:
        while at < len(reply) and reply[at] in " \t\r\n,":
            at += 1
        try:
            row, at = decoder.raw_decode(reply, at)
        except ValueError:
            return rows
        if isinstance(row, dict):
            rows.append(row)


def _text(value, limit):
    return mn.clean_text(value, limit)


NUMBER_WORDS = mn.NUMBER_DIGITS
_numbers = mn.numbers_in


def apply(item, row, index):
    """Put one checked reply row on the item. Quotes the transcript does not hold are not kept as said."""
    story = _text(row.get("user_story"), 400)
    if story:   # "As user, I want" -> "As a user, I want"
        story = re.sub(r"^As (?!a |an |the )(\w)", lambda m: ("As an " if m.group(1).lower() in "aeio" else "As a ")
                       + m.group(1), story)
        item["user_story"] = story
    item["category"] = row.get("category") if row.get("category") in CATEGORIES else None
    item["clarity"] = row.get("clarity") if row.get("clarity") in CLARITY else None
    item["clarify_question"] = _text(row.get("question"), 300) if item["clarity"] == "unclear" else None
    quote = _text(row.get("priority_quote"), mn.MAX_EVIDENCE_CHARS)
    if row.get("priority") in PRIORITIES and quote and mn.evidence_found(quote, index):
        item["priority"], item["priority_quote"] = row["priority"], quote
    else:   # a priority nobody said is a guess: none
        item["priority"], item["priority_quote"] = None, None
    said, suggested = [], []
    for entry in row.get("acceptance_said") or []:
        if not isinstance(entry, dict):
            continue
        criterion = _text(entry.get("criterion"), 300)
        quote = _text(entry.get("quote"), mn.MAX_EVIDENCE_CHARS)
        if not criterion:
            continue
        if quote and mn.evidence_found(quote, index):
            if not mn.same_units(criterion, quote):   # "تانيتين" written as "two minutes": wrong, dropped
                continue
            said.append({"criterion": criterion, "quote": quote})
        else:   # the client did not say it in these words: it is the AI's suggestion
            suggested.append(criterion)
    for entry in row.get("acceptance_suggested") or []:
        criterion = _text(entry, 300)
        if criterion:
            suggested.append(criterion)
    allowed = _numbers(" ".join([item.get("text") or "", item.get("evidence") or ""]
                                + [s["criterion"] + " " + s["quote"] for s in said]))
    suggested = [c for c in suggested if _numbers(c) <= allowed]   # a number nobody said is a guess
    seen = {mn.normalize(s["criterion"]) for s in said}
    item["acceptance_said"] = said[:MAX_SAID]
    item["acceptance_suggested"] = [c for c in dict.fromkeys(suggested) if mn.normalize(c) not in seen][:MAX_SUGGESTED]
    if item["clarity"] == "unclear":
        item["needs_review"] = True


def write(items, text, project, llm=None):
    """Write every requirement item in place. -> error message or None. Never raises."""
    requirements = [i for i in items if i.get("type") == "requirement"]
    if not requirements:
        return None
    index = mn.evidence_index(text)
    if llm is None:
        from syntrace_ai.assistant import llm_client
        llm = llm_client.for_step("write")
    failed = 0
    # (batch, asked again): requirements a reply left out (cut off, or skipped) are asked once more, in a
    # smaller call
    queue = [(requirements[start:start + BATCH], False) for start in range(0, len(requirements), BATCH)]
    while queue:
        batch, again = queue.pop(0)
        prompt = WRITE_PROMPT.format(project=project, max_suggested=MAX_SUGGESTED,
                                     requirements="\n".join(_block(n, i, text) for n, i in enumerate(batch)))
        try:
            rows = _parse(llm(prompt))
        except Exception as exc:
            log.warning("requirement writing failed: %s", type(exc).__name__)
            failed += len(batch)
            continue
        by_id = {}
        for row in rows:
            try:
                by_id.setdefault(int(row.get("id")), row)
            except (TypeError, ValueError):
                continue
        missing = [item for n, item in enumerate(batch) if n not in by_id]
        for n, item in enumerate(batch):
            if n in by_id:
                apply(item, by_id[n], index)
        if missing and not again:
            log.warning("requirement writing: %d of %d left out, asking again", len(missing), len(batch))
            half = max(1, len(missing) // 2)
            queue += [(missing[:half], True)] + ([(missing[half:], True)] if missing[half:] else [])
        else:
            failed += len(missing)
    link_conditions(requirements)
    return f"{failed} requirement(s) could not be written" if failed else None


def link_conditions(requirements):
    """A limit said right after a requirement and extracted as its own item ("results in under two
    seconds" after "voice commands") is also a condition of that requirement: added to its
    acceptance_said with the client's words, so the draft and the review show it where it belongs.
    Only the closest requirement before it that shares a content word gets it: a limit on voice
    results is not a condition of the release notes said a line earlier."""
    words = lambda r: mn.content_words(f"{r.get('text') or ''} {r.get('evidence') or ''}")
    for b in requirements:
        if not b.get("lines") or not _numbers(b.get("text")) or b.get("category") not in (None, "non_functional"):
            continue
        near = [a for a in requirements if a is not b and a.get("lines")
                and 0 < min(b["lines"]) - max(a["lines"]) <= 2 and words(a) & words(b)]
        if not near:
            continue
        a = min(near, key=lambda r: min(b["lines"]) - max(r["lines"]))
        if not any(s["quote"] == b["evidence"] for s in a.get("acceptance_said") or []):
            a.setdefault("acceptance_said", []).append({"criterion": b["text"], "quote": b["evidence"]})


def node_props(item):
    """The writer's fields as Neo4j properties (lists of maps are stored as JSON)."""
    return {"user_story": item.get("user_story"), "category": item.get("category"),
            "clarity": item.get("clarity"), "clarify_question": item.get("clarify_question"),
            "priority": item.get("priority"), "priority_quote": item.get("priority_quote"),
            "acceptance_said": json.dumps(item.get("acceptance_said") or [], ensure_ascii=False),
            "acceptance_suggested": item.get("acceptance_suggested") or []}


def from_node(item):
    """The stored fields back as the API returns them."""
    try:
        said = json.loads(item.get("acceptance_said") or "[]")
    except ValueError:
        said = []
    item["acceptance_said"] = said if isinstance(said, list) else []
    item["acceptance_suggested"] = item.get("acceptance_suggested") or []
    return item
