"""
meetings/text.py
Pure text work on a meeting source, with no I/O and no model: reading a PDF, masking contact numbers,
splitting, and the evidence check every extracted item must pass (the model's quote must be in the
transcript, in order), with the line numbers it came from. Plus the guard that refuses blame about a
person whatever the model returned.

Nothing here imports the graph, the web framework or a model client, so it is tested with plain strings
(tests/architecture check: test_architecture.py).
"""
import base64
import binascii
import difflib
import io
import re

from syntrace_ai.meetings.errors import MeetingError

MAX_PDF_BYTES = 10 * 1024 * 1024
MAX_EVIDENCE_CHARS = 500
MIN_EVIDENCE_CHARS = 8
MASK = "[NUMBER]"
EMAIL_MASK = "[EMAIL]"


_AR_TO_LATIN = str.maketrans({"ب": "b", "ت": "t", "ث": "t", "ج": "g", "ح": "h", "خ": "k", "د": "d", "ذ": "d",
                               "ر": "r", "ز": "z", "س": "s", "ش": "s", "ص": "s", "ض": "d", "ط": "t", "ظ": "z",
                               "ع": "", "غ": "g", "ف": "f", "ق": "k", "ك": "k", "ل": "l", "م": "m", "ن": "n",
                               "ه": "h", "ة": "", "ا": "", "أ": "", "إ": "", "آ": "", "و": "", "ي": "", "ى": "",
                               "ئ": "", "ؤ": "", "ء": ""})


def _skeleton_latin(name):
    s = name.lower().replace("sh", "s").replace("kh", "k").replace("th", "t").replace("ph", "f")
    s = s.replace("j", "g").replace("c", "k").replace("q", "k").replace("x", "ks")
    return "".join(ch for ch in s if ch.isalpha() and ch not in "aeiouyw")


def name_in(name, text):
    """A person's name written in Latin letters is found in Arabic text too: "Fatma" in "فاطمة هتبعت",
    "Mohamed" in "محمد", by comparing consonants. -> True when a word of the text has the same ones."""
    if not name or not text:
        return False
    if normalize(name) in normalize(text):
        return True
    wanted = _skeleton_latin(name)
    if len(wanted) < 2:
        return False
    for word in re.findall(r"[\u0600-\u06FF]+", text):
        word = re.sub(r"^(?:وال|بال|لل|ال|و|ب|ل)(?=..)", "", word)
        if word.translate(_AR_TO_LATIN) == wanted:
            return True
    return False


_STOP = {"the", "a", "an", "to", "of", "and", "or", "in", "on", "for", "with", "is", "be", "it", "that", "must",
         "should", "will", "can", "may", "system", "app", "application", "user", "users", "able", "allow", "allows",
         "support", "supports", "provide", "this", "their", "its", "by", "from", "as", "are"}


def _stem(word):
    for end in ("ing", "ed", "es", "s"):
        if word.endswith(end) and len(word) - len(end) >= 4:
            return word[:-len(end)]
    return word


# A deadline the model translated ("Thursday") while the client said it in Arabic: the words to look for
_DUE_WORDS = {"saturday": ("السبت",), "sunday": ("الأحد", "الحد"), "monday": ("الاتنين", "الإثنين", "الاثنين"),
              "tuesday": ("التلات", "الثلاثاء", "التلاتاء"), "wednesday": ("الأربع", "الاربع", "الأربعاء"),
              "thursday": ("الخميس",), "friday": ("الجمعة", "الجمعه"),
              "today": ("النهارده", "النهاردة", "اليوم"), "tomorrow": ("بكرة", "بكره", "غدا"),
              "next week": ("الأسبوع الجاي", "الاسبوع الجاي", "الأسبوع اللي جاي", "الاسبوع اللي جاي"),
              "end of the week": ("آخر الأسبوع", "اخر الاسبوع"), "next month": ("الشهر الجاي",)}


def said_due(due, evidence):
    """The deadline as it was said: `due` itself when the quote has it, else the Arabic words the quote
    uses for the same day ("Thursday" -> "الخميس"); None when the quote names no such day."""
    if not due:
        return None
    norm = normalize(evidence)
    if normalize(due) in norm:
        return due
    asked = due.lower()
    for english, arabic in _DUE_WORDS.items():
        if english in asked:
            for word in arabic:
                if normalize(word) in norm:
                    return word
    return None


# Time units as said in Egyptian Arabic (and English), for checking that a written criterion kept the
# unit the client used: "تانيتين" is two seconds, never two minutes.
UNIT_WORDS = {"second": ("تانية", "تانيه", "تانيتين", "تواني", "ثانية", "ثانيه", "ثانيتين", "ثواني", "second"),
              "minute": ("دقيقة", "دقيقه", "دقيقتين", "دقايق", "دقائق", "minute"),
              "hour": ("ساعة", "ساعه", "ساعتين", "ساعات", "hour"),
              "day": ("يومين", "أيام", "ايام", " يوم", "day"),
              "week": ("أسبوع", "اسبوع", "أسبوعين", "اسبوعين", "أسابيع", "week")}
_UNIT_EN = re.compile(r"\b(second|minute|hour|day|week)s?\b", re.I)


_ARABIC = re.compile(r"[\u0600-\u06FF]")


def due_in_english(due, evidence):
    """The deadline in English for the English notes, checked against the quote: the model's "Thursday"
    stays when the quote says الخميس; an Arabic deadline ("قبل يوم الأحد") becomes "before Sunday";
    None when the quote names no such day (a guess). Arabic with no known day word stays as said."""
    said = said_due(due, evidence)
    if not said:
        return None
    if not _ARABIC.search(due):
        return due
    norm = normalize(due)
    for english, words in _DUE_WORDS.items():
        if any(normalize(w) in norm for w in words):
            name = english.title() if english.endswith("day") and english not in ("today",) else english
            return ("before " if "قبل" in due else "") + name
    return said


def owner_in_english(owner, text):
    """An owner written in Arabic letters ("زينب") takes the Latin spelling the item's English text
    uses for the same name ("Zainab will open the server")."""
    if not owner or not _ARABIC.search(owner):
        return owner
    for word in re.findall(r"\b[A-Z][a-z]{2,}\b", text or ""):
        if name_in(word, owner):
            return word
    return owner


def units_in(value):
    """The time units a text uses ({"second", ...}), from Arabic or English words."""
    norm = " " + normalize(value) + " "
    return {unit for unit, words in UNIT_WORDS.items() if any(normalize(w) in norm for w in words)}


def same_units(criterion, quote):
    """False when the criterion names a time unit the quote did not use (it changed "seconds" to
    "minutes"); True when either has no unit."""
    written = {m.lower() for m in _UNIT_EN.findall(criterion or "")}
    said = units_in(quote)
    return not written or not said or written <= said


def content_words(value):
    """The words that carry meaning (no stop words, light stemming), for comparing two item texts."""
    return {_stem(w) for w in re.findall(r"\w+", (value or "").lower()) if w not in _STOP and len(w) > 2}


def near_duplicate(a, b, share=0.6):
    """Two item texts that say the same thing in other words: their content words (light stemming)
    overlap by at least `share` of all the content words they use."""
    wa, wb = content_words(a), content_words(b)
    if not wa or not wb:
        return False
    return len(wa & wb) / len(wa | wb) >= share


def clean_text(value, limit):
    """A model's string on one line and cut to `limit`; None for anything else or empty."""
    if not isinstance(value, str):
        return None
    value = " ".join(value.split())
    return value[:limit] if value else None


# ---------- 1. Text in ----------

PAGE_BREAK = "\f"   # between PDF pages, so a quote's offset tells its page


def pdf_text(pdf_base64, page_breaks=False):
    """Text of a PDF. A scanned PDF has no text layer, and OCR is out of scope. With page_breaks, pages
    are separated by a form feed, so page_of() can tell a quote's page."""
    try:
        data = base64.b64decode(pdf_base64, validate=True)
    except (binascii.Error, ValueError):
        raise MeetingError("pdfBase64 is not valid base64") from None
    if len(data) > MAX_PDF_BYTES:
        raise MeetingError("PDF is larger than 10 MB", 413)
    from pypdf import PdfReader
    try:
        reader = PdfReader(io.BytesIO(data))
        pages = [(page.extract_text() or "").strip() for page in reader.pages]
    except Exception as exc:
        raise MeetingError(f"PDF could not be read: {type(exc).__name__}", 422) from None
    if page_breaks:     # every page keeps its place, an empty one too, so the count stays right
        text = f"\n{PAGE_BREAK}\n".join(pages)
    else:
        text = "\n\n".join(p for p in pages if p)
    if len(text.replace(PAGE_BREAK, "").strip()) < 20:
        raise MeetingError("the PDF has no readable text; scanned PDFs need OCR, which is not supported", 422)
    return text


def page_of(text, offset):
    """The 1-based page of a character in text made by pdf_text(page_breaks=True); None without breaks."""
    if not text or PAGE_BREAK not in text or offset is None or not 0 <= int(offset) <= len(text):
        return None
    return text[:int(offset)].count(PAGE_BREAK) + 1


# ---------- 2. Masking ----------

_DIGIT = r"[0-9٠-٩۰-۹]"
_DIGIT_RUN = re.compile(rf"(?<![\w+])\+?{_DIGIT}(?:[ \-\.]?{_DIGIT}){{6,}}(?![\w])")
_ACCOUNT = re.compile(r"(?<![A-Za-z0-9])[A-Z]{2}[0-9]{2}(?: ?[A-Z0-9]){10,30}(?![A-Za-z0-9])")   # IBAN
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
_DATE = re.compile(rf"{_DIGIT}{{4}}[-/.]{_DIGIT}{{1,2}}[-/.]{_DIGIT}{{1,2}}|{_DIGIT}{{1,2}}[-/.]{_DIGIT}{{1,2}}[-/.]{_DIGIT}{{4}}")
NUMBER_WORDS = {
    "zero", "oh", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
    "صفر", "زيرو", "واحد", "اتنين", "اثنين", "إتنين", "تلاتة", "ثلاثة", "تلاته", "ثلاثه", "اربعة", "أربعة",
    "اربعه", "أربعه", "خمسة", "خمسه", "ستة", "سته", "سبعة", "سبعه", "تمانية", "ثمانية", "تمانيه", "ثمانيه",
    "تسعة", "تسعه", "عشرة", "عشره", "مية", "ميه", "مائة",
}
_WORD = re.compile(r"[^\s.,،؛;:!?()\[\]\"'«»]+")
SPOKEN_NUMBER_WORDS = 5


def _mask_spoken_numbers(text):
    """A phone number said aloud ("زيرو مية اتنين أربعة ...") is a run of number words."""
    words = list(_WORD.finditer(text))
    spans, run = [], []
    for match in words:
        if match.group().lower() in NUMBER_WORDS:
            run.append(match)
            continue
        if len(run) >= SPOKEN_NUMBER_WORDS:
            spans.append((run[0].start(), run[-1].end()))
        run = []
    if len(run) >= SPOKEN_NUMBER_WORDS:
        spans.append((run[0].start(), run[-1].end()))
    for start, end in reversed(spans):
        text = text[:start] + MASK + text[end:]
    return text


def mask_sensitive(text):
    """Phone, card, account and IBAN numbers, written or spoken, and email addresses."""
    text = _EMAIL.sub(EMAIL_MASK, text)
    text = _ACCOUNT.sub(lambda m: MASK if sum(c.isdigit() for c in m.group()) >= 8 else m.group(), text)
    text = _DIGIT_RUN.sub(lambda m: m.group() if _DATE.fullmatch(m.group()) else MASK, text)
    return _mask_spoken_numbers(text)


# ---------- 3. Splitting ----------

def split_text(text, size, overlap):
    """Parts of about `size` characters that end at a line break when one is near."""
    text = text.strip()
    if len(text) <= size:
        return [text] if text else []
    parts, start = [], 0
    while start < len(text):
        end = min(start + size, len(text))
        if end < len(text):
            cut = text.rfind("\n", start + size // 2, end)
            if cut > start:
                end = cut
        part = text[start:end].strip()
        if part:
            parts.append(part)
        if end >= len(text):
            break
        start = max(end - overlap, start + 1)
    return parts


# ---------- 4. Evidence ----------

_TASHKEEL = re.compile(r"[ً-ْٰـ]")
_SPEAKER = re.compile(r"^[^:\n]{1,40}:\s*", re.MULTILINE)
_PUNCT = re.compile(r"[\"'“”‘’«»`.,،؛;:!?؟()\[\]{}\-–—_*]")


def normalize(text):
    text = _TASHKEEL.sub("", text or "").lower()
    text = (text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي")
            .replace("ة", "ه").replace("ؤ", "و").replace("ئ", "ي"))
    text = _PUNCT.sub(" ", text)
    return " ".join(text.split())


# a caption time at the start of a line ("[02:07] ", "00:01:15 ", "(1:02:03)"): not words anyone said,
# and left in it splits a sentence that runs on into the next caption line ("blog page [02:07] template")
_TIMESTAMP = re.compile(r"^[ \t]*[\[(]?\d{1,2}:\d{2}(?::\d{2})?(?:[.,]\d+)?[\])]?[ \t]*", re.MULTILINE)


def without_times(text):
    return _TIMESTAMP.sub("", text or "")


# sounds that carry no words: a quote may leave them out, and a listener's "Mm-hmm ." line said in the
# middle of a sentence ("... anyway ,\nMarketing: Mm-hmm .\nPM: um for our designer ...") must not split it
FILLERS = {"um", "umm", "uh", "uhm", "er", "erm", "ah", "eh", "mm", "mmm", "hmm", "mhm", "hm", "huh",
           "uh-huh", "mm-hmm", "آآ",
           # transcription marks of the AMI/QMSum corpus ("{disfmarker}", "{vocalsound}"): not words said
           "disfmarker", "vocalsound", "nonvocalsound"}
_FILLER_WORDS = {normalize(w) for w in FILLERS} | {part for w in FILLERS for part in normalize(w).split()}


def without_fillers(normalized):
    return " ".join(w for w in normalized.split() if w not in _FILLER_WORDS)


def evidence_index(source_text):
    """The source as the evidence check reads it: with and without speaker labels, caption times dropped,
    and without speaker labels and filler sounds."""
    source_text = without_times(source_text)
    bare = normalize(without_times(_SPEAKER.sub("", source_text)))
    return normalize(source_text), bare, without_fillers(bare)


_EVIDENCE_SPLIT = re.compile(r"\.\.\.|…|(?<=[.!?؟])\s+")


def evidence_parts(evidence):
    """The quote's parts: split at an ellipsis or between sentences, so a quote that joins two sentences
    said on different lines ("... يتشحن. push بس ...") is checked sentence by sentence."""
    return [p for p in (normalize(x) for x in _EVIDENCE_SPLIT.split(evidence or "")) if p]


def _in_order(parts, body):
    at = 0
    for part in parts:
        found = body.find(part, at)
        if found < 0:
            return False
        at = found + len(part)
    return True


def evidence_found(evidence, index):
    """Every part of the quote appears in the source, in the order quoted (filler sounds aside)."""
    parts = evidence_parts(evidence)
    if not parts or sum(len(p) for p in parts) < MIN_EVIDENCE_CHARS:
        return False
    if any(_in_order(parts, body) for body in index[:2]):
        return True
    bare = [without_fillers(p) for p in parts]
    return len(index) > 2 and all(bare) and _in_order(bare, index[2])


REPAIR_RATIO = 0.9   # how close a quote must be to a source line to count as a copying slip


def repair_evidence(evidence, source_text):
    """A quote the model copied with a small slip (a letter dropped: "لاندين" for "لاندينج") is put back
    to the source's own words: each part of the quote must be at least REPAIR_RATIO similar to a stretch
    of one line, in order. -> the source's words for the quote, or None when any part is not close."""
    lines = [without_times(_SPEAKER.sub("", without_times(line))).strip() for line in (source_text or "").split("\n")]
    found, start = [], 0
    for part in evidence_parts(evidence):
        size, best = len(part.split()), (0.0, None, None)
        for n in range(start, len(lines)):
            words = lines[n].split()
            normal = [normalize(w) for w in words]
            for width in {max(1, size - 1), size, size + 1}:
                for at in range(0, max(1, len(words) - width + 1)):
                    ratio = difflib.SequenceMatcher(None, part, " ".join(w for w in normal[at:at + width] if w)).ratio()
                    if ratio > best[0]:
                        best = (ratio, n, " ".join(words[at:at + width]))
        if best[0] < REPAIR_RATIO or len(part) < MIN_EVIDENCE_CHARS:
            return None
        found.append(best[2])
        start = best[1]
    return " ... ".join(found) if found else None


SPLIT_MIN_WORDS = 3     # each piece of a quote joined without " ... " must be at least this many words
SPLIT_MAX_PIECES = 3
SPLIT_MAX_GAP = 400     # characters of source the quote may skip between two pieces


def split_evidence(evidence, source_text):
    """A quote that joins two places of the source without " ... " ("... three sort of buckets Yeah ,
    yeah I think that's a good idea" when the buckets sentence goes on before the answer) is put back
    as the pieces the source has, in order and close together, joined with " ... ". The pieces are the
    model's own words (already copied from the source); nothing is added. -> the quote, or None."""
    body = evidence_index(source_text)[2]
    tokens = (evidence or "").split()
    flat = [(word, n) for n, token in enumerate(tokens) for word in without_fillers(normalize(token)).split()]
    pieces, i, at_least, last_end = [], 0, 0, None
    while i < len(flat):
        found = None
        for j in range(len(flat), i + SPLIT_MIN_WORDS - 1, -1):
            phrase = " ".join(word for word, _ in flat[i:j])
            at = body.find(phrase, at_least)
            if at >= 0 and (last_end is None or at - last_end <= SPLIT_MAX_GAP):
                found = (j, at + len(phrase))
                break
        if not found:
            return None
        j, last_end = found
        at_least = last_end
        pieces.append((flat[i][1], flat[j - 1][1]))
        i = j
        if len(pieces) > SPLIT_MAX_PIECES:
            return None
    if len(pieces) < 2:
        return None
    text = " ... ".join(" ".join(tokens[a:b + 1]) for a, b in pieces)
    return text if evidence_found(text, evidence_index(source_text)) else None


def evidence_lines(evidence, source_text):
    """1-based line numbers of the source that hold the evidence, found by code (never by the model).
    Each part of the quote (split at an ellipsis) is located in the normalized text, speaker labels
    ignored, and its span is mapped back to lines. [] when it cannot be placed."""
    for clean in (lambda body: body, without_fillers):   # a quote that left out "um" or a "Mm-hmm ." line
        joined, starts = [], []
        pos = 0
        for line in (source_text or "").split("\n"):
            body = clean(normalize(without_times(_SPEAKER.sub("", without_times(line)))))
            if body and joined:
                pos += 1   # the one space between two lines; an empty line adds none
            starts.append(pos)
            if body:
                joined.append(body)
                pos += len(body)
        text = " ".join(joined)
        lines, start = set(), 0
        for part in (clean(p) for p in evidence_parts(evidence)):
            at = text.find(part, start) if part else -1
            if at < 0 and part:
                at = text.find(part)
            if at < 0:
                lines = None
                break
            start = at + len(part)
            first = max(n for n, s in enumerate(starts) if s <= at)
            last = max(n for n, s in enumerate(starts) if s <= at + len(part) - 1)
            lines.update(range(first + 1, last + 2))
        if lines:
            return sorted(lines)
    return []


# Blame or judgement about a person is never a project item, whatever the model decided. Checked on the
# item's text and its evidence; a work problem stays possible when said without blame ("waiting for the
# Jira setup"). Words are matched after normalize(), so spelling variants of Arabic letters still match.
BLAME_WORDS = (
    "مش مركز", "مش مركزه", "مركزش", "مقصر", "مقصره", "مهمل", "مهمله", "كسلان", "كسلانه", "مستهتر",
    "مستهتره", "اتاخر علينا", "بيتاخر علينا", "متاخر علينا", "مش بيرد", "مش بترد", "مبيردش", "مبتردش",
    "ملوش لازمه", "فاشل", "فاشله", "lazy", "careless", "unprofessional",
    "slacking", "keeps delaying us", "always late", "incompetent", "irresponsible",
)
_BLAME = tuple(normalize(w) for w in BLAME_WORDS)


def blames_a_person(text):
    body = f" {normalize(text)} "
    return any(f" {w} " in body for w in _BLAME)


# numbers said as digits or words, for checking that a model did not bring a number nobody said
NUMBER_DIGITS = {"one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7",
                "eight": "8", "nine": "9", "ten": "10", "hundred": "100", "thousand": "1000",
                "واحد": "1", "اتنين": "2", "تانيتين": "2", "يومين": "2", "أسبوعين": "2", "اسبوعين": "2",
                "دقيقتين": "2", "ساعتين": "2", "تلات": "3", "تلاتة": "3", "تلاته": "3", "ثلاث": "3", "ثلاثة": "3", "أربعة": "4", "اربعة": "4",
                "خمسة": "5", "عشرة": "10", "مية": "100", "ألف": "1000", "الف": "1000"}


def numbers_in(text):
    """The numbers a text holds, digits or number words (English and Egyptian Arabic)."""
    text = (text or "").lower().translate(str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789"))
    found = {n.replace(",", "") for n in re.findall(r"\d[\d,]*(?:\.\d+)?", text)}
    found |= {NUMBER_DIGITS[w] for w in re.findall(r"\w+", text) if w in NUMBER_DIGITS}
    return found
