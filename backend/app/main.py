import logging

from fastapi import FastAPI
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api import dictionaries, exhibits, identify, similar
from app.config import settings
from app.db import db_cursor
from app.rate_limit import limiter
from app.similarity import index_size

logger = logging.getLogger(__name__)

# Startup guard: DEV_MOCK_IDENTIFY=true w production = startup fail.
# W prod chcemy realne wywołania Claude, a mock oszukiwałby usera.
if settings.is_production and settings.dev_mock_identify:
    raise RuntimeError(
        "DEV_MOCK_IDENTIFY=true jest niedozwolone gdy ENVIRONMENT=production. "
        "Wyłącz mock lub ustaw environment=development."
    )
if settings.is_production and not settings.anthropic_api_key:
    raise RuntimeError(
        "ANTHROPIC_API_KEY jest wymagane w production (skoro mock wyłączony)."
    )

# W production wyłącz OpenAPI docs — zmniejsza reconnaissance surface.
# API nie jest publiczne (Bearer-only), ale czemu ułatwiać mapowanie endpointów?
_docs_kwargs = {} if not settings.is_production else {
    "docs_url": None,
    "redoc_url": None,
    "openapi_url": None,
}

app = FastAPI(
    title="Inwentaryzacja Mobile API",
    description="Backend dla mobilnej apki Qt Android — identify/similar/exhibits.",
    version="0.0.6",
    **_docs_kwargs,
)

# Rate limiting (patrz app/rate_limit.py). Handler zwraca 429 + Retry-After.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(dictionaries.router)
app.include_router(identify.router)
app.include_router(exhibits.router)
app.include_router(similar.router)


@app.get("/health")
def health() -> dict:
    """
    Health probe.

    **Production**: minimalna odpowiedź `{"status":"ok","version":...}` —
    żeby nie ułatwiać reconnaissance (brak info o bazie, liczbie eksp., mock).
    **Development**: pełne stats dla Welcome panel w apce.
    """
    base = {"status": "ok", "version": app.version}

    if settings.is_production:
        return base

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
        **base,
        "database": settings.mariadb_database,
        "exhibits_count": exhibits_count,
        "clip_index_size": clip_index,
        "mock_identify": settings.dev_mock_identify,
    }
