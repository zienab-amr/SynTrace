"""
build_graph.py
Bulk import: بيقرا كل ملفات all_tickets/*.json ويمرّرها على ingest.upsert_issue
(نفس الدالة اللي بيستخدمها webhook_handler.py بالظبط).

  python build_graph.py                  # import عادي (idempotent)
  python build_graph.py --force         # يعيد كتابة الـ state حتى لو updated مش أحدث
  python build_graph.py --wipe-all      # يمسح كل الـ graph الأول (لازم تكتبي WIPE)
  python build_graph.py --tenant acme --dir tickets_acme
"""
import argparse
import glob
import json
import os
import sys
from collections import Counter

from dotenv import load_dotenv
from neo4j import GraphDatabase

load_dotenv()   # before importing ingest: it reads TENANT_ID at import time

import ingest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="all_tickets")
    ap.add_argument("--tenant", default=ingest.DEFAULT_TENANT)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--wipe-all", action="store_true")
    args = ap.parse_args()
    if not args.tenant:
        sys.exit("tenant مش محدد: حطي TENANT_ID في الـ .env أو استخدمي --tenant")

    driver = GraphDatabase.driver(
        os.getenv("NEO4J_URI"), auth=(os.getenv("NEO4J_USER"), os.getenv("NEO4J_PASSWORD")))

    if args.wipe_all:
        if input("ده هيمسح كل الـ nodes والـ edges في الـ database. اكتبي WIPE للتأكيد: ") != "WIPE":
            sys.exit("اتلغى.")
        with driver.session() as s:
            s.run("MATCH (n) DETACH DELETE n")
        print(">>> Graph wiped. شغّلي setup_constraints.py لو لسه ما اتشغلش.\n")

    files = sorted(glob.glob(os.path.join(args.dir, "*.json")))
    print(f">>> tenant={args.tenant} | {len(files)} files from {args.dir}/")
    if not ingest.FIELD_META:
        print("    (تنبيه: field_meta.json مش موجود، الـ Sprint هيتكشف من شكل القيمة بس. "
              "الملف ده بييجي من الـ export المحلي)")

    stats = Counter()
    failures = []
    for i, path in enumerate(files, 1):
        try:
            with open(path, "r", encoding="utf-8") as f:
                issue = json.load(f)
            with driver.session() as session:
                result = session.execute_write(
                    lambda tx: ingest.upsert_issue(tx, issue, args.tenant, force=args.force,
                                                   payload_mode="full"))
        except Exception as exc:   # one bad file must not abort (or hide) the rest of the load
            result = "failed"
            failures.append((os.path.basename(path), f"{type(exc).__name__}: {exc}"))
        stats[result] += 1
        if i % 25 == 0 or i == len(files):
            print(f"  [{i}/{len(files)}] {dict(stats)}")
    driver.close()
    print(f"\n>>> Done. {dict(stats)}")
    for name, err in failures:
        print(f"  ✗ {name}: {err}")
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()