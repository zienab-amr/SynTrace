"""
meetings/document.py
The meeting notes as a text the user edits (by hand, or by asking the agent), and the edits taken back to
the items, so the PDF, Jira and the project's memory say the same thing.

The text is the one meetings/notes.py builds: headings, then "- " lines; a line's details are in brackets
at its end ("(owner: Fatma; due: الخميس; priority: high; needs review)"). Each edited line is matched to the
item it came from (same type, closest wording); a line with no match is an item the user added, and an item
whose line is gone is one the user removed. Items the user wrote have no quote from the meeting, and say so.

Pure: no graph, no model.
"""
import difflib
import re

from syntrace_ai.meetings import text as tx
from syntrace_ai.meetings.notes import PROPOSALS, PROPOSED, SECTIONS, accepted_text

TYPE_OF = {heading.lower(): kind for kind, heading in SECTIONS}
TYPE_WORD = {heading.lower().rstrip("s"): kind for kind, heading in SECTIONS}   # "requirement", "action item"
OTHER = {"overview", "topics discussed", "out of scope", PROPOSALS.lower()}
MATCH_RATIO = 0.45
DETAILS = re.compile(r"\s*\(([^()]*)\)\s*$")
NUMBER = re.compile(r"\d+(?:[.,]\d+)?")


def sections(text):
    """-> [(heading, [line text without "- "])], in order. Lines before any heading go under ""."""
    out, current = [], ("", [])
    for raw in (text or "").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("- ") or line.startswith("* "):
            current[1].append(line[2:].strip())
        else:
            if current[0] or current[1]:
                out.append(current)
            current = (line.rstrip(":"), [])
    if current[0] or current[1]:
        out.append(current)
    return out


def line_fields(line):
    """'Send the design. (owner: Fatma; due: الخميس)' -> ('Send the design.', {'owner': 'Fatma', 'due': ...})."""
    fields = {}
    match = DETAILS.search(line)
    if match:
        known = False
        for part in match.group(1).split(";"):
            part = part.strip()
            name, _, value = part.partition(":")
            name = name.strip().lower()
            if name in ("owner", "due", "priority") and value.strip():
                fields[name], known = value.strip(), True
            elif part.lower() == "needs review":
                fields["needs_review"], known = True, True
            elif part.lower() in TYPE_WORD:   # a proposal's line says what it would become
                fields["type"], known = TYPE_WORD[part.lower()], True
        if known:
            line = line[:match.start()].rstrip()
    return line.strip(), fields


def _ratio(a, b):
    return difflib.SequenceMatcher(None, tx.normalize(a), tx.normalize(b)).ratio()


def diff(items, edited):
    """What the edited text changes in the items.
    -> {"changed": [{"uid", "text", "owner", "due", "priority", "needs_review"}], "added": [{"type", "text", ...}],
        "removed": [uid], "summary": str | None}
    The text is the whole document: an item whose line is gone (its section too) is removed. A line under
    "Out of scope" or "Proposals to review" keeps whichever item it matches; a new line there is not added
    (its type is unknown). A proposal's line moved under its type's heading is accepted: it loses the
    "Proposed: " mark and no longer needs review."""
    changed, added, kept, summary = [], [], set(), None

    def take(text, fields, candidates, proposals=False):
        best = max(candidates, key=lambda i: _ratio(text, accepted_text(i.get("text") or "")), default=None)
        if best is None or _ratio(text, accepted_text(best.get("text") or "")) < MATCH_RATIO:
            return False
        kept.add(best["uid"])
        before = best.get("text") or ""
        if proposals and before.startswith(PROPOSED):
            text = PROPOSED + accepted_text(text)   # still a proposal: the heading stands for the mark
        change = {k: v for k, v in fields.items() if k in ("owner", "due", "priority") and v != best.get(k)}
        if before.startswith(PROPOSED) and not text.startswith(PROPOSED):
            change["needs_review"] = False   # accepted
        if text != before:
            change["text"] = text
        if change:
            changed.append(dict(change, uid=best["uid"]))
        return True

    for heading, lines in sections(edited):
        name = heading.strip().lower()
        if name == "overview":
            summary = " ".join(lines).strip() or None
            continue
        kind = TYPE_OF.get(name)
        proposals = name == PROPOSALS.lower()
        if not kind and name != "out of scope" and not proposals:
            continue
        for line in lines:
            text, fields = line_fields(line)
            if not text:
                continue
            candidates = [i for i in items if i["uid"] not in kept and (not kind or i.get("type") == kind)]
            if not take(text, fields, candidates, proposals) and kind:
                added.append(dict({k: v for k, v in fields.items() if k in ("owner", "due", "priority")},
                                  type=kind, text=text))
    removed = [i["uid"] for i in items if i["uid"] not in kept and i.get("type") in TYPE_OF.values()]
    return {"changed": changed, "added": added, "removed": removed, "summary": summary}


def new_numbers(proposal, *allowed):
    """Numbers in the agent's proposal that appear nowhere in what it was given: a rewrite must not
    invent limits, prices or dates."""
    seen = set()
    for text in allowed:   # "تلات تواني" in the meeting allows "3 seconds" in the proposal
        seen |= set(NUMBER.findall(text or "")) | tx.numbers_in(text)
    return sorted(set(NUMBER.findall(proposal or "")) - seen)
