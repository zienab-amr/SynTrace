"""
meetings/classify.py
The second look at a meeting's items (MEETING_CLASSIFY=groq): the long-context model (ERNIE) finds the
points and copies their quotes from the whole transcript; gpt-oss on Groq then decides, for each one,
its type, whether it is an unsettled proposal, and its owner, from the item and its quote only. Finding
needs the whole meeting; judging needs a model that follows the rules the same way each run.

Nothing new is found here and no quote changes: an owner the quote does not name is dropped, as in
check_item. When the call fails or its reply is broken, the items stay as the first model left them.
"""
import json
import logging
import os
import re

log = logging.getLogger("syntrace.meetings")

TYPES = ("requirement", "decision", "action_item", "blocker", "open_question")
PROPOSED = "Proposed: "
BATCH = 12   # items per call: a short reply that is never cut off (30 at once came back broken)

CLASSIFY_PROMPT = """You check the items found in a {kind} for the project "{project}".
Each item below was found by another model, with the exact quote from the meeting that supports it and
"next": the few lines said right after the quote (how the others answered: agreed, objected, moved on).
For each item decide, from its text, quote and next lines only:
- "type": one of
  "requirement" (what the product must do or have: a feature, a limit, a format, who may use it),
  "decision" (a choice the team settled in this meeting about how, with what, when or in what scope the
  work is done: a tool, a design, a schedule, what is in or out),
  "action_item" (a task someone will do),
  "blocker" (something stopping the work, with its reason),
  "open_question" (an unresolved question or something still to confirm).
- "proposed": true when it is an idea someone put forward that is not settled in the quote or the next
  lines (a design, how something could work, a presentation or research finding, "maybe", "we could",
  "ممكن"); false when it was asked for, or the quote or the next lines show it agreed or decided
  ("yeah, let's do that", "okay, so we go with", "تمام نعمل كده"). Only a requirement or a decision can be
  proposed.
- "owner": for an action item, the person or role the quote names as doing it (the one who says they
  will, or the one asked or addressed: "Zeinab, can you ...", "marketing to look into ..."), in English
  letters; otherwise null. Never guess from who might be speaking.
Use the same rule for the same kind of sentence every time. Examples:
- quote "the client needs to export reports as PDF" -> requirement, proposed false
- quote "I think we could use Redis for the cache", next "yeah let's go with Redis" -> decision, proposed false
- quote "I think we could use Redis for the cache", next "hmm, let's see the cost first" -> decision, proposed true
- quote "my research shows most remotes use infrared" -> it is a finding: requirement, proposed true
- quote "Zeinab, can you open the server tomorrow?" -> action_item, owner "Zeinab"
- quote "we decided last week to use Flutter" -> decision, proposed false (settled, even if before)

Return one JSON object and no other text: {{"items": [{{"n": 1, "type": "...", "proposed": false, "owner": null}}, ...]}}
with one entry for every item, in the same order.

Items:
{items}
"""


def enabled():
    return os.getenv("MEETING_CLASSIFY", "").strip().lower() == "groq" and bool(os.getenv("GROQ_API_KEY"))


NEXT_LINES = 3
NEXT_CHARS = 400


def _next(item, source_lines):
    """The lines said right after the item's quote: how the meeting answered it."""
    if not source_lines or not item.get("lines"):
        return ""
    last = max(item["lines"])   # 1-based
    return " | ".join(line.strip() for line in source_lines[last:last + NEXT_LINES] if line.strip())[:NEXT_CHARS]


def _listing(batch, start, source_lines=None):
    lines = []
    for n, item in enumerate(batch, start):
        text = item["text"][len(PROPOSED):] if item["text"].startswith(PROPOSED) else item["text"]
        row = {"n": n, "type": item["type"], "text": text, "quote": item["evidence"][:400]}
        after = _next(item, source_lines)
        if after:
            row["next"] = after
        lines.append(json.dumps(row, ensure_ascii=False))
    return "\n".join(lines)


def _parse(reply):
    """The {"items": [...]} object in the reply, wherever it is (a code fence or words around it)."""
    reply = reply or ""
    decoder = json.JSONDecoder()
    for start in [m.start() for m in re.finditer(r"\{", reply)]:
        try:
            found, _ = decoder.raw_decode(reply, start)
        except ValueError:
            continue
        rows = found.get("items") if isinstance(found, dict) else None
        if isinstance(rows, list):
            return {int(r["n"]): r for r in rows if isinstance(r, dict) and str(r.get("n", "")).isdigit()}
    raise ValueError("no items object")


def apply(item, row, owner_ok):
    """One item as the second look decided it. `owner_ok(owner, item)` says whether the quote names the owner."""
    kind = row.get("type") if row.get("type") in TYPES else item["type"]
    bare = item["text"][len(PROPOSED):] if item["text"].startswith(PROPOSED) else item["text"]
    proposed = row.get("proposed") is True and kind in ("requirement", "decision")
    owner = row.get("owner") if isinstance(row.get("owner"), str) and row.get("owner").strip() else None
    if kind != "action_item":
        owner = None
    elif owner and not owner_ok(owner, item):
        owner = item.get("owner")   # a name the quote does not hold is a guess: keep the first model's
    else:
        owner = owner or item.get("owner")
    changed = {**item, "type": kind, "text": (PROPOSED + bare) if proposed else bare, "owner": owner}
    if proposed:
        changed["needs_review"] = True
    return changed


def classify(items, llm, kind, project, owner_ok, source_text=None):
    """-> the items with type, proposal mark and owner from the second look; unchanged on failure.
    `source_text` (the masked transcript) gives each item the lines said after its quote."""
    source_lines = source_text.split("\n") if source_text else None
    out = []
    for start in range(0, len(items), BATCH):
        batch = items[start:start + BATCH]
        prompt = CLASSIFY_PROMPT.format(kind=kind, project=project, items=_listing(batch, start + 1, source_lines))
        try:
            try:
                rows = _parse(llm(prompt))
            except ValueError:   # a broken reply once: ask again
                rows = _parse(llm(prompt))
        except Exception as exc:   # the first model's items stay: a second look is never worse than none
            log.warning("classify: second look unavailable (%s: %s): items kept as found", type(exc).__name__, str(exc)[:200])
            out.extend(batch)
            continue
        out.extend(apply(item, rows[n], owner_ok) if n in rows else item
                   for n, item in enumerate(batch, start + 1))
    return out
