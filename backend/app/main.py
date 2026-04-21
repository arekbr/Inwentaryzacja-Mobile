from fastapi import FastAPI

from app.api import dictionaries
from app.config import settings

app = FastAPI(
    title="Inwentaryzacja Mobile API",
    description="Backend dla mobilnej apki Qt Android — identify/similar/exhibits.",
    version="0.0.2",
)

app.include_router(dictionaries.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "version": app.version,
        "database": settings.mariadb_database,
    }
