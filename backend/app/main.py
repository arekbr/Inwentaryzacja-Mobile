import logging

from fastapi import FastAPI

from app.api import dictionaries, exhibits, identify, similar
from app.config import settings
from app.db import db_cursor
from app.similarity import index_size

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Inwentaryzacja Mobile API",
    description="Backend dla mobilnej apki Qt Android — identify/similar/exhibits.",
    version="0.0.6",
)

app.include_router(dictionaries.router)
app.include_router(identify.router)
app.include_router(exhibits.router)
app.include_router(similar.router)


@app.get("/health")
def health() -> dict:
    """Status backendu + podstawowe liczby (do Welcome panel w apce)."""
    exhibits_count = 0
    try:
        with db_cursor() as cur:
            cur.execute("SELECT COUNT(*) AS c FROM eksponaty")
            row = cur.fetchone()
            exhibits_count = int(row["c"]) if row else 0
    except Exception as e:
        logger.warning("health: DB count failed: %s", e)

    clip_index = 0
    try:
        clip_index = index_size()
    except Exception as e:
        logger.warning("health: CLIP index size failed: %s", e)

    return {
        "status": "ok",
        "version": app.version,
        "database": settings.mariadb_database,
        "exhibits_count": exhibits_count,
        "clip_index_size": clip_index,
        "mock_identify": settings.dev_mock_identify,
    }
