"""
meetings/merge.py
Two readings of the same meeting by the long-context model (MEETING_READS=2): it finds a somewhat
different set of points each time (in the lab 53-79% of points came back in both readings), so the
second reading catches what the first one missed.

A point found in both readings is kept once. A point only one reading found is kept too, with
needs_review, so the reviewer looks at it: nothing either reading found is lost. When the two readings
gave the same point different types, it is kept as the first reading had it, with needs_review.
"""
import difflib

MATCH = 0.55


def _lines(item):
    return set(item.get("lines") or [])


def alike(a, b):
    """How much two items look like the same point: their lines overlap, and their texts are alike."""
    la, lb = _lines(a), _lines(b)
    if not la or not lb or not (la & lb):
        return 0.0
    ratio = difflib.SequenceMatcher(None, a["text"].lower(), b["text"].lower()).ratio()
    return ratio + (0.5 if la == lb else 0.25 * len(la & lb) / len(la | lb))


def pairs(first, second, threshold=MATCH):
    """-> [(i, j)]: the best one-to-one matches between the two readings."""
    scored = sorted(((alike(a, b), i, j) for i, a in enumerate(first) for j, b in enumerate(second)), reverse=True)
    used_a, used_b, out = set(), set(), []
    for score, i, j in scored:
        if score < threshold:
            break
        if i in used_a or j in used_b:
            continue
        used_a.add(i)
        used_b.add(j)
        out.append((i, j))
    return out


def merge(first, second):
    """-> (items, counts): one list of the points either reading found."""
    matched = pairs(first, second)
    in_both = {i for i, _ in matched}
    taken = {j for _, j in matched}
    out, disagreed = [], 0
    for i, item in enumerate(first):
        item = dict(item)
        if i not in in_both:
            item["needs_review"] = True
        else:
            other = second[[j for a, j in matched if a == i][0]]
            if other["type"] != item["type"] or other["text"].startswith("Proposed:") != item["text"].startswith("Proposed:"):
                item["needs_review"] = True
                disagreed += 1
            if not item.get("owner") and other.get("owner"):
                item["owner"] = other["owner"]
        out.append(item)
    for j, item in enumerate(second):
        if j not in taken:
            out.append(dict(item, needs_review=True))
    return out, {"both": len(matched), "first_only": len(first) - len(matched),
                 "second_only": len(second) - len(matched), "type_disagreed": disagreed}


def add_missing(found, missing):
    """The review mode: the first reading as it is, plus the points the review says it missed (a point the
    review repeats anyway is not added twice). The additions need review."""
    repeated = {j for _, j in pairs(found, missing)}
    added = [dict(item, needs_review=True) for j, item in enumerate(missing) if j not in repeated]
    return list(found) + added, {"first": len(found), "added": len(added), "repeated": len(repeated)}
