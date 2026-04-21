import uuid
from contextlib import contextmanager
from typing import Iterator

import pymysql
from pymysql.cursors import DictCursor

from app.config import settings


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
    """
    cur.execute(f"SELECT id FROM {table} WHERE name = %s", (name,))  # noqa: S608
    row = cur.fetchone()
    if row:
        return row["id"]

    new_id = str(uuid.uuid4())
    if extra_cols:
        cols = ["id", "name", *extra_cols.keys()]
        placeholders = ", ".join(["%s"] * len(cols))
        values = [new_id, name, *extra_cols.values()]
        cur.execute(
            f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders})",  # noqa: S608
            values,
        )
    else:
        cur.execute(
            f"INSERT INTO {table} (id, name) VALUES (%s, %s)",  # noqa: S608
            (new_id, name),
        )
    return new_id
