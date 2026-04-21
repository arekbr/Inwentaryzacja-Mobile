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
