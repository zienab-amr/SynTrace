"""
build_embeddings.py
بيحسب embedding لكل WorkItem (incremental: بيعيد بس اللي نصه اتغيّر) ويخزّنه على الـ node.

  python build_embeddings.py              # اللي اتغيّر/الجديد بس
  python build_embeddings.py --force      # الكل من الأول
Ollama لازم يكون شغال وفيه:  ollama pull bge-m3
"""
import argparse
import os
import sys

from dotenv import load_dotenv

from embeddings import EMBED_MODEL, embed_batches, embedding_text, text_hash

load_dotenv()


def embed_work_items(tenant_id, uids=None, force=False):
    return embed_work_items_detailed(tenant_id, uids, force)[0]


def embed_work_items_detailed(tenant_id, uids=None, force=False):
    """-> (stored, failed). Each batch is stored as it finishes; failed items retry on the next run."""
    from query_engine import run_query, get_driver
    rows = run_query(
        """
        MATCH (w:WorkItem {tenant_id: $t})
        WHERE w.summary IS NOT NULL AND ($uids IS NULL OR w.uid IN $uids)
        RETURN w.uid AS uid, w.key AS key, w.issuetype AS issuetype, w.summary AS summary,
               w.components AS components, w.labels AS labels,
               w.description_text AS description_text, w.description_intro AS description_intro,
               w.embedding_hash AS hash
        """, t=tenant_id, uids=uids)
    todo = []
    for r in rows:
        text = embedding_text(r.data())
        h = text_hash(text)
        if force or r["hash"] != h:
            todo.append((r["uid"], text, h, r["key"]))
    print(f">>> {len(rows)} work items, {len(todo)} need (re)embedding [{EMBED_MODEL}]")
    if not todo:
        return 0, []
    stored, failed = 0, []
    with get_driver().session() as session:
        for indexes, vectors, errors in embed_batches([item[1] for item in todo]):
            for i, vec, error in zip(indexes, vectors, errors):
                uid, _, h, key = todo[i]
                if vec is None:
                    failed.append((key, error))
                    print(f"  x {key}: {error}")
                    continue
                session.run("MATCH (w:WorkItem {uid: $uid}) "
                            "SET w.embedding = $vec, w.embedding_hash = $h, w.embedding_model = $m",
                            uid=uid, vec=vec, h=h, m=EMBED_MODEL)
                stored += 1
            print(f"  [{indexes[-1] + 1}/{len(todo)}] stored={stored} failed={len(failed)}")
    print(f">>> Done: {stored} embeddings stored, {len(failed)} failed.")
    return stored, failed


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--tenant", default=os.getenv("TENANT_ID", "syntrace"))
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    _stored, _failed = embed_work_items_detailed(a.tenant, force=a.force)
    sys.exit(1 if _failed else 0)