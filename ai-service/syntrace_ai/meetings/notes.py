"""Meeting notes built in code from the checked items, so the notes list every requirement, decision,
action item, blocker and open question the review shows, and nothing the code refused. The model only
adds the summary and one line per topic discussed."""

SECTIONS = (("requirement", "Requirements"), ("decision", "Decisions"), ("action_item", "Action items"),
            ("blocker", "Blockers"), ("open_question", "Open questions"))
PROPOSALS = "Proposals to review"
PROPOSED = "Proposed: "
MAX_TOPIC_LINES = 200
RESERVED = {h.lower() for _, h in SECTIONS} | {"overview", "topics discussed", "out of scope", PROPOSALS.lower()}


def is_proposal(item):
    """An idea the meeting did not settle (MEETING_PROPOSAL_MODE=flag): its text starts "Proposed: "."""
    return (item.get("text") or "").startswith(PROPOSED)


def accepted_text(text):
    """A proposal the reviewer accepted: its text without the "Proposed: " mark."""
    return text[len(PROPOSED):].strip() if (text or "").startswith(PROPOSED) else text


def _topics(model_notes):
    """The model's detailed topics: each "## title" becomes a heading line, its "- " details stay. Other
    headings the model wrote are dropped."""
    lines = []
    for line in (model_notes or "").splitlines():
        line = line.strip()
        if line.startswith("## ") and len(line) > 3:
            title = line[3:].strip().rstrip(":")
            # a topic called like a section ("Decisions") must not read as that section when edited
            lines.append(f"Topic: {title}" if title.lower() in RESERVED else title)
        elif line.startswith("- ") and len(line) > 2:
            lines.append(line)
    return lines[:MAX_TOPIC_LINES]


def _line(item, proposal=False):
    text = item.get("text") or ""
    extra = []
    if proposal:   # under "Proposals to review": the mark is the heading; the type says what it would become
        text = accepted_text(text)
        extra.append(dict(SECTIONS).get(item.get("type"), item.get("type") or "").lower().rstrip("s"))
    if item.get("type") == "action_item":
        if item.get("owner"):
            extra.append(f"owner: {item['owner']}")
        if item.get("due"):
            extra.append(f"due: {item['due']}")
    if item.get("type") == "requirement" and item.get("priority"):
        extra.append(f"priority: {item['priority']}")
    if item.get("relation") in ("change", "conflict", "dropped") and item.get("relation_note"):
        extra.append(item["relation_note"])
    if item.get("needs_review"):
        extra.append("needs review")
    return f"- {text}" + (f" ({'; '.join(extra)})" if extra else "")


def _id(item):
    return item.get("id") or item.get("uid")


def build(summary, model_notes, items, out_of_scope=()):
    """-> the notes as text: Overview, Topics discussed, then the items by type, then Out of scope.
    `out_of_scope` holds the ids of items the meeting postponed or refused."""
    out_of_scope = set(out_of_scope or ())
    parts = []
    if summary:
        parts += ["Overview", f"- {summary}"]
    topics = _topics(model_notes)
    if topics:
        parts += ["Topics discussed"] + topics
    parts += item_sections(items, out_of_scope)
    return "\n".join(parts) or None


def item_sections(items, out_of_scope=()):
    """The item part of the notes as lines: the settled items by type, then the proposals still to review
    (kept apart so the requirements count only what was asked for or agreed), then Out of scope."""
    out_of_scope = set(out_of_scope or ())
    parts = []
    for kind, heading in SECTIONS:
        lines = [_line(i) for i in items
                 if i.get("type") == kind and _id(i) not in out_of_scope and not is_proposal(i)]
        if lines:
            parts += [heading] + lines
    proposals = [_line(i, proposal=True) for i in items if is_proposal(i) and _id(i) not in out_of_scope]
    if proposals:
        parts += [PROPOSALS] + proposals
    later = [_line(i) for i in items if _id(i) in out_of_scope]
    if later:
        parts += ["Out of scope"] + later
    return parts


def refresh(text, items, out_of_scope=()):
    """The notes once the review is over: the Overview and topics the text has, and the item sections built
    again from the items as approved, so the PDF holds no deleted item and no "Proposed" mark on an accepted
    one. -> text or None."""
    keep = []
    for line in (text or "").splitlines():
        name = line.strip().rstrip(":").lower()
        if not line.strip().startswith(("- ", "* ")) and name in RESERVED - {"overview", "topics discussed"}:
            break   # the first item section: everything from here is rebuilt
        keep.append(line)
    parts = [line for line in keep if line.strip()] + item_sections(items, out_of_scope)
    return "\n".join(parts) or None
