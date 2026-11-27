"""
names.py
People's names across Arabic and Latin spellings.

Jira keeps each person's display name, usually in Latin letters ("Martina Sameh"). Users ask in
Arabic ("تذاكر مارتينا" or "مارتينا سامح"), and the model sometimes writes names back in Arabic.

- match(text, people): the people a name in any spelling refers to. Both spellings are reduced to a
  consonant skeleton (vowels and weak letters dropped, look-alike sounds merged), so "مارتينا سامه",
  "مارتينا سامح" and "Martina Sameh" all become "mrtn smh".
- latinize(answer, people): every Arabic spelling of a known person in an answer is replaced by the
  person's display name, so answers always show names as Jira writes them.
- people(ctx): everyone who appears in the company's allowed projects, cached for a short time.
"""
import re
import threading
import time

from syntrace_ai.graph.query_engine import _scope, run_query

CACHE_SECONDS = 300
MIN_SKELETON = 3       # shorter names match too many words
_ARABIC = re.compile(r"[\u0600-\u06FF]")
_ARABIC_WORD = re.compile(r"[\u0621-\u063A\u0641-\u0652\u0671-\u06D3]+")   # letters only, not Arabic punctuation

# Arabic letters -> sound classes. Vowels and weak letters map to "" and are dropped.
_AR = {
    "ا": "", "أ": "", "إ": "", "آ": "", "ء": "", "ئ": "", "ؤ": "", "ى": "", "ة": "", "ع": "",
    "و": "", "ي": "",
    "ب": "b", "پ": "b", "ت": "t", "ث": "t", "ط": "t", "ج": "g", "چ": "g", "ح": "h", "ه": "h",
    "خ": "K", "د": "d", "ض": "d", "ذ": "z", "ز": "z", "ظ": "z", "ر": "r", "س": "s", "ص": "s",
    "ش": "S", "غ": "G", "ف": "f", "ڤ": "f", "ق": "k", "ك": "k", "گ": "g", "ل": "l", "م": "m", "ن": "n",
}
# Latin spellings -> the same classes. Digraphs first.
_LATIN_PAIRS = (("sh", "S"), ("ch", "S"), ("kh", "K"), ("gh", "G"), ("th", "t"), ("dh", "z"),
                ("ph", "f"), ("ou", ""), ("x", "ks"))
_LATIN = {"a": "", "e": "", "i": "", "o": "", "u": "", "y": "", "w": "", "j": "g", "q": "k",
          "c": "k", "p": "b", "v": "f"}

_lock = threading.Lock()
_people = {}   # (tenant, projects) -> (time, [names])


def has_arabic(text):
    return bool(_ARABIC.search(text or ""))


def _collapse(skeleton):
    return re.sub(r"(.)\1+", r"\1", skeleton)


def skeleton(word):
    """The consonant skeleton of one word in Arabic or Latin letters."""
    word = (word or "").strip()
    # A first y or w is a consonant (Youssef, Waleed), unlike the same letter inside a name, so
    # Youssef and Sofia keep different skeletons.
    if has_arabic(word):
        lead = {"ي": "y", "و": "w"}.get(word[:1], "")
        out = lead + "".join(_AR.get(ch, "") for ch in word[1:] if lead) if lead else \
            "".join(_AR.get(ch, "") for ch in word)
    else:
        out = re.sub(r"[^a-z]", "", word.lower())
        out = re.sub(r"c(?=[eiy])", "s", out)   # Grace, Cindy: a soft c sounds like s
        lead = out[:1] if out[:1] in ("y", "w") else ""
        out = out[len(lead):]
        for pair, code in _LATIN_PAIRS:
            out = out.replace(pair, code)
        out = lead + "".join(_LATIN.get(ch, ch) for ch in out)
    return _collapse(out)


def skeletons(word):
    """A final ه is sometimes a ة (فاطمه) and sometimes an h (سامه), so both readings are kept."""
    full = skeleton(word)
    if has_arabic(word) and word.endswith("ه") and full.endswith("h"):
        return {full, full[:-1]}
    return {full}


def _words(name):
    return [w for w in re.split(r"[\s._\-]+", name or "") if w]


def _close(a, b):
    """Same skeleton, or one letter apart for longer names (Saeed / Said, Zienab / Zeinab)."""
    if a == b:
        return True
    if min(len(a), len(b)) < 4 or abs(len(a) - len(b)) > 1:
        return False
    if len(a) == len(b):
        return sum(x != y for x, y in zip(a, b)) <= 1
    short, long_ = sorted((a, b), key=len)
    return any(long_[:i] + long_[i + 1:] == short for i in range(len(long_)))


def match(text, people):
    """The people that a name refers to, best matches only. Every word of the name must match a
    different word of the person's name, so "مارتينا" finds Martina Sameh and "مارتينا سامح" finds
    only her. An exact Latin match always wins."""
    text = (text or "").strip()
    if not text:
        return []
    exact = [p for p in people if p.lower() == text.lower()]
    if exact:
        return exact
    wanted = [v for v in (skeletons(w) - {""} for w in _words(text)) if v]
    if not wanted or sum(max(map(len, v)) for v in wanted) < 2:
        return []
    scored = []
    for person in people:
        parts = [skeleton(w) for w in _words(person)]
        free, score = list(parts), 0
        for w in wanted:
            hit = next((p for p in free if p in w), None) or \
                next((p for p in free if p and any(_close(p, x) for x in w)), None)
            if hit is None:
                break
            free.remove(hit)
            score += 2 if hit in w else 1
            if parts and hit == parts[0] and len(wanted) == 1:   # a first name means the first name
                score += 1
        else:
            scored.append((score, person))
    if not scored:
        return []
    best = max(s for s, _ in scored)
    return sorted(p for s, p in scored if s == best)


def latinize(answer, people):
    """Replace Arabic spellings of known people in an answer with their display names. A two-word
    Arabic span must match a full two-word name; a single word must be a first name that only one
    person has, at least three consonants long."""
    if not answer or not people or not has_arabic(answer):
        return answer
    latin_people = [p for p in people if not has_arabic(p)]
    full = {}
    first = {}
    for person in latin_people:
        parts = [skeleton(w) for w in _words(person)]
        if len(parts) >= 2 and all(parts[:2]):
            full.setdefault((parts[0], parts[1]), set()).add(person)
        if parts and len(parts[0]) >= MIN_SKELETON:
            first.setdefault(parts[0], set()).add(person)

    tokens = list(_ARABIC_WORD.finditer(answer))

    def split(token):
        """("و", "فاطمة") for "وفاطمة": a one-letter conjunction stays in front of the name."""
        word = token.group()
        if len(word) > 3 and word[0] in "وفبل" and skeletons(word[1:]) & first.keys():
            return word[0], word[1:]
        return "", word
    replacements, i = [], 0
    while i < len(tokens):
        word = tokens[i]
        prefix, text = split(word)
        lead = prefix + " " if prefix else ""
        if i + 1 < len(tokens) and answer[word.end():tokens[i + 1].start()].strip() == "":
            hits = set().union(*(full.get((a, b), set()) for a in skeletons(text)
                                 for b in skeletons(tokens[i + 1].group())))
            if hits and len(hits) == 1:
                replacements.append((word.start(), tokens[i + 1].end(), lead + next(iter(hits))))
                i += 2
                continue
        hits = set().union(*(first.get(a, set()) for a in skeletons(text)))
        if hits and len(hits) == 1 and not _prefixed(text):
            replacements.append((word.start(), word.end(), lead + next(iter(hits))))
        i += 1
    for start, end, name in reversed(replacements):
        answer = answer[:start] + name + answer[end:]
    return answer


def _prefixed(word):
    """Arabic words that start with "ال" are ordinary words, not names."""
    return word.startswith("ال")


def people(ctx):
    """Everyone assigned, reporting, commenting, logging time or changing tickets in the allowed projects."""
    key = (ctx.tenant_id, tuple(ctx.allowed_projects))
    now = time.monotonic()
    with _lock:
        cached = _people.get(key)
        if cached and now - cached[0] < CACHE_SECONDS:
            return cached[1]
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $tenant})-[:ASSIGNED_TO|REPORTED_BY]->(p:Person) "
        "WHERE w.project_key IN $allowed RETURN DISTINCT p.displayName AS name "
        "UNION MATCH (w:WorkItem {tenant_id: $tenant})-[:HAS_COMMENT|HAS_WORKLOG|HAD_CHANGE]->()"
        "-[:WRITTEN_BY|LOGGED_BY|CHANGED_BY]->(p:Person) "
        "WHERE w.project_key IN $allowed RETURN DISTINCT p.displayName AS name",
        **_scope(ctx))
    names = sorted({r["name"] for r in rows if r.get("name")})
    with _lock:
        if len(_people) > 500:
            _people.clear()
        _people[key] = (now, names)
    return names


def resolve(text, ctx):
    """-> (names, note). One name: use it. Several: ask which. None: say so. Never raises."""
    try:
        found = match(text, people(ctx))
    except Exception:
        return [], None
    if len(found) == 1:
        return found, None
    if found:
        return found, f"Several people match {text}: {', '.join(found)}. Ask which one is meant."
    return [], f"Nobody named {text} works in these projects."
