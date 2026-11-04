"""
semantic_search.py
بحث بالمعنى للأسئلة اللي من غير ticket key ("إيه التذاكر المتعلقة بالـ authentication؟").
الفلترة بـ tenant و allowed_projects بتحصل جوه الـ Cypher، قبل ما أي vector يتحسب أو يوصل للـ LLM.

  python semantic_search.py "tickets about login"     # بيطبع أعلى النتايج بالـ scores (للمعايرة)
"""
import math
import os
import sys
import time

from embeddings import embed_texts
from query_engine import AccessContext, build_item, default_context, run_query

SEMANTIC_K = int(os.getenv("SEMANTIC_K", "10"))
# Calibrated with calibrate_search.py. Scores of related and unrelated questions overlap for
# Arabic questions on English tickets, so this only removes clear noise and the LLM picks the
# relevant tickets.
SEMANTIC_MIN_SCORE = float(os.getenv("SEMANTIC_MIN_SCORE", "0.35"))
CACHE_TTL = 60

_CACHE = {}


def _load_vectors(ctx: AccessContext):
    cache_key = (ctx.tenant_id, tuple(sorted(ctx.allowed_projects)))
    hit = _CACHE.get(cache_key)
    if hit and time.time() - hit[0] < CACHE_TTL:
        return hit[1]
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $tenant})
        WHERE w.project_key IN $allowed AND w.embedding IS NOT NULL
        OPTIONAL MATCH (w)-[:ASSIGNED_TO]->(p:Person)
        RETURN w.uid AS uid, w.key AS rkey, w.summary AS summary, w.status AS status, w.url AS url,
               w.project_key AS project, p.displayName AS assignee, w.embedding AS emb
        """, tenant=ctx.tenant_id, allowed=list(ctx.allowed_projects))
    items = []
    for r in rows:
        v = r["emb"]
        norm = math.sqrt(sum(x * x for x in v)) or 1.0
        items.append((r, v, norm))
    _CACHE[cache_key] = (time.time(), items)
    return items


def _live_uids(uids, ctx):
    """The vector cache can be up to CACHE_TTL old; a deleted issue must not come back from it."""
    rows = run_query(
        "MATCH (w:WorkItem {tenant_id: $tenant}) WHERE w.project_key IN $allowed AND w.uid IN $uids "
        "RETURN w.uid AS uid", tenant=ctx.tenant_id, allowed=list(ctx.allowed_projects), uids=uids)
    return {r["uid"] for r in rows}


def semantic_search(text, ctx: AccessContext, k=SEMANTIC_K, min_score=SEMANTIC_MIN_SCORE):
    """بترجّع list من الـ items (نفس شكل build_item) + score، الأعلى الأول."""
    items = _load_vectors(ctx)
    if not items:
        return []
    q = embed_texts([text])[0]
    qn = math.sqrt(sum(x * x for x in q)) or 1.0
    scored = []
    for r, v, norm in items:
        score = sum(a * b for a, b in zip(q, v)) / (qn * norm)
        if score >= min_score:
            scored.append((score, r))
    scored.sort(key=lambda t: t[0], reverse=True)
    candidates = scored[:k * 3]
    live = _live_uids([r["uid"] for _, r in candidates], ctx) if candidates else set()
    allowed = set(ctx.allowed_projects)
    hits = []
    for score, r in [c for c in candidates if c[1]["uid"] in live][:k]:
        item = build_item(r["rkey"], r["summary"], r["status"], r["url"],
                          r["assignee"], r["project"], allowed)
        item["score"] = round(score, 3)
        hits.append(item)
    return hits


if __name__ == "__main__":
    query = " ".join(sys.argv[1:]) or "authentication"
    for h in semantic_search(query, default_context(), k=10, min_score=0.0):
        print(f"{h['score']:.3f}  {h['key']:<14} {h['summary']}")