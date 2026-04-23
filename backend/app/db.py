import uuid
from contextlib import contextmanager
from typing import Iterator

import pymysql
from pymysql.cursors import DictCursor

from app.config import settings

# Whitelist dla `lookup_or_insert` — tylko te tabele można edytować z API.
# Bandit B608 sygnalizuje f-string SQL — tu jest OK bo caller hardcoded,
# ale defensywny assert zapobiega przypadkowemu przekazaniu user-controlled
# table name w przyszłych refaktorach.
_ALLOWED_LOOKUP_TABLES = frozenset({"types", "vendors", "models", "statuses", "storage_places"})

# Whitelist kolumn które mogą trafić do `extra_cols` w lookup_or_insert.
# Obecnie jedyna użyta to `vendor_id` dla tabeli `models`.
_ALLOWED_EXTRA_COLS = frozenset({"vendor_id"})


def _connect() -> pymysql.connections.Connection:
    return pymysql.connect(
        host=settings.mariadb_host,
        port=settings.mariadb_port,
        user=settings.mariadb_user,
        password=settings.mariadb_password,
        database=settings.mariadb_database,
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
    )


@contextmanager
def db_cursor() -> Iterator[DictCursor]:
    """Context manager: otwiera połączenie, daje kursor, commit + close na wyjściu."""
    conn = _connect()
    try:
        with conn.cursor() as cur:
            yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def lookup_or_insert(
    cur: DictCursor,
    table: str,
    name: str,
    extra_cols: dict | None = None,
) -> str:
    """
    Szuka wpisu po kolumnie `name` w tabeli słownikowej. Zwraca istniejące ID
    albo wstawia nowy wiersz (UUID4) i zwraca jego ID. Port 1:1 z
    `importuj_mariadb.py::lookup_or_insert()`.

    Defensywnie waliduje `table` i `extra_cols.keys()` przeciw whitelistcie —
    zapobiega SQLi gdyby kiedykolwiek caller przekazał user-controlled wartości.
    """
    if table not in _ALLOWED_LOOKUP_TABLES:
        raise ValueError(f"lookup_or_insert: tabela {table!r} poza whitelistcie")
    if extra_cols:
        bad = set(extra_cols.keys()) - _ALLOWED_EXTRA_COLS
        if bad:
            raise ValueError(f"lookup_or_insert: extra_cols {bad!r} poza whitelistcie")

    cur.execute(f"SELECT id FROM {table} WHERE name = %s", (name,))  # noqa: S608  # nosec B608 — table whitelisted
    row = cur.fetchone()
    if row:
        return row["id"]

    new_id = str(uuid.uuid4())
    if extra_cols:
        cols = ["id", "name", *extra_cols.keys()]
        placeholders = ", ".join(["%s"] * len(cols))
        values = [new_id, name, *extra_cols.values()]
        cur.execute(
            f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders})",  # noqa: S608  # nosec B608
            values,
        )
    else:
        cur.execute(
            f"INSERT INTO {table} (id, name) VALUES (%s, %s)",  # noqa: S608  # nosec B608
            (new_id, name),
        )
    return new_id
