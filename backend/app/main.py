from fastapi import FastAPI

from app.api import dictionaries, exhibits, identify, similar
from app.config import settings

app = FastAPI(
    title="Inwentaryzacja Mobile API",
    description="Backend dla mobilnej apki Qt Android — identify/similar/exhibits.",
    version="0.0.5",
)

app.include_router(dictionaries.router)
app.include_router(identify.router)
app.include_router(exhibits.router)
app.include_router(similar.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "version": app.version,
        "database": settings.mariadb_database,
    }
