"""
Batch — zbuduj indeks LanceDB z embeddingów CLIP dla istniejących eksponatów.

Bierze PIERWSZE zdjęcie każdego eksponatu z tabeli `photos` (po MIN(id) ordering),
liczy CLIP embedding, wrzuca do LanceDB.

Uruchomienie (z katalogu `backend/`):
    .venv/bin/python scripts/build_embeddings.py

Opcje: --limit N (do debug), --overwrite (domyślnie overwrite).
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

# Dodaj backend/ do sys.path żeby import `app.*` działał z scripts/
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np

from app.db import db_cursor
from app.similarity import _get_db, embed_image, TABLE_NAME


SELECT_FIRST_PHOTO = """
SELECT e.id AS exhibit_id, e.name AS name,
       v.name AS vendor, m.name AS model,
       p.photo AS photo
FROM eksponaty e
LEFT JOIN vendors v ON e.vendor_id = v.id
LEFT JOIN models m ON e.model_id = m.id
INNER JOIN (
    SELECT eksponat_id, MIN(id) AS first_photo_id
    FROM photos
    GROUP BY eksponat_id
) fp ON fp.eksponat_id = e.id
INNER JOIN photos p ON p.id = fp.first_photo_id
ORDER BY e.name
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=None, help="Limit rekordów (dla debug)")
    ap.add_argument("--overwrite", action="store_true", default=True,
                    help="Nadpisz istniejący indeks (domyślnie TAK)")
    args = ap.parse_args()

    print("▶ Ładuję listę eksponatów z MariaDB…")
    sql = SELECT_FIRST_PHOTO
    if args.limit:
        sql = sql + f"\nLIMIT {int(args.limit)}"

    with db_cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()
    print(f"▶ Do indeksowania: {len(rows)} eksponatów z pierwszym zdjęciem")

    if not rows:
        print("❌ Brak eksponatów ze zdjęciami — nie ma co indeksować")
        return 1

    items: list[dict] = []
    start = time.time()
    fails = 0
    for i, row in enumerate(rows, 1):
        try:
            emb: np.ndarray = embed_image(bytes(row["photo"]))
            items.append({
                "exhibit_id": row["exhibit_id"],
                "name": row["name"] or "",
                "vendor": row["vendor"] or "",
                "model": row["model"] or "",
                "vector": emb.tolist(),
            })
            if i % 50 == 0:
                elapsed = time.time() - start
                rate = i / elapsed
                eta = (len(rows) - i) / rate
                print(f"  [{i}/{len(rows)}] {rate:.1f}/s, ETA {eta:.0f}s")
        except Exception as e:
            fails += 1
            print(f"  ✗ {row['exhibit_id']} ({row.get('name')}): {e}")

    elapsed = time.time() - start
    print(f"▶ Embeddings: {len(items)} OK, {fails} fail, {elapsed:.1f}s")

    if not items:
        print("❌ Brak udanych embeddingów")
        return 1

    print(f"▶ Zapisuję do LanceDB (tabela `{TABLE_NAME}`)…")
    db = _get_db()
    if TABLE_NAME in db.list_tables().tables and args.overwrite:
        db.drop_table(TABLE_NAME)
    tbl = db.create_table(TABLE_NAME, data=items)
    print(f"✓ LanceDB gotowe: {tbl.count_rows()} rekordów")
    print(f"  Lokalizacja: {db.uri}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
