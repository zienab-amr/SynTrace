"""
embeddings.py
Embedding عن طريق Ollama المحلي (bge-m3: بيدعم عربي/إنجليزي/مختلط من غير نسخ منفصلة).
"""
import hashlib
import math
import os

import requests

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
EMBED_MODEL = os.getenv("EMBED_MODEL", "bge-m3")
EMBED_TIMEOUT = int(os.getenv("EMBED_TIMEOUT_SECONDS", "300"))   # slow CPUs need minutes per batch
EMBED_BATCH_SIZE = int(os.getenv("EMBED_BATCH_SIZE", "8"))


class EmbeddingError(RuntimeError):
    """`status` is the HTTP status from Ollama; None means Ollama could not be reached."""
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


def _post(batch):
    try:
        r = requests.post(f"{OLLAMA_URL}/api/embed",
                          json={"model": EMBED_MODEL, "input": batch}, timeout=EMBED_TIMEOUT)
    except requests.RequestException as e:
        raise EmbeddingError(f"Ollama embed failed: {e}") from e
    if not r.ok:
        raise EmbeddingError(f"Ollama embed failed: HTTP {r.status_code}: {r.text[:300]}", r.status_code)
    embs = r.json().get("embeddings")
    if not embs or len(embs) != len(batch):
        raise EmbeddingError("Ollama returned an unexpected embeddings payload", r.status_code)
    if not all(math.isfinite(x) for v in embs for x in v):
        raise EmbeddingError("Ollama returned a non-finite embedding", r.status_code)
    return embs


def embed_texts(texts, batch_size=EMBED_BATCH_SIZE):
    out = []
    for i in range(0, len(texts), batch_size):
        out.extend(_post(texts[i:i + batch_size]))
    return out


def _embed_one_by_one(text):
    """(vector, used_chars, error). A text Ollama rejects is retried shorter."""
    error = None
    for limit in (len(text), 1000, 500):
        if limit > len(text):
            continue
        try:
            return _post([text[:limit]])[0], limit, None
        except EmbeddingError as e:
            if e.status is None:
                raise
            error = str(e)
    return None, 0, error


def embed_batches(texts, batch_size=EMBED_BATCH_SIZE):
    """Yield (indexes, vectors, errors) per batch so progress can be stored as it is made. A batch
    Ollama rejects is retried text by text, so one bad text does not stop the others. vectors[i]
    is None when that text failed. An unreachable Ollama raises EmbeddingError."""
    for start in range(0, len(texts), batch_size):
        batch = texts[start:start + batch_size]
        indexes = list(range(start, start + len(batch)))
        try:
            yield indexes, _post(batch), [None] * len(batch)
            continue
        except EmbeddingError as e:
            if e.status is None:
                raise
        vectors, errors = [], []
        for text in batch:
            vector, _used, error = _embed_one_by_one(text)
            vectors.append(vector)
            errors.append(error)
        yield indexes, vectors, errors


def embedding_text(props, max_chars=2000):
    """
    النص اللي بيتحوّل لـ vector. الـ status مش داخل فيه (بيتغير كتير، ومش جزء من المعنى).
    """
    parts = [f"{props.get('key')} | {props.get('issuetype') or ''}",
             props.get("summary") or ""]
    if props.get("components"):
        parts.append("Components: " + ", ".join(props["components"]))
    if props.get("labels"):
        parts.append("Labels: " + ", ".join(props["labels"]))
    parts.append(props.get("description_text") or props.get("description_intro") or "")
    return "\n".join(p for p in parts if p).strip()[:max_chars]


def text_hash(text):
    return hashlib.sha1(f"{EMBED_MODEL}\n{text}".encode("utf-8")).hexdigest()