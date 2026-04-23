from fastapi import APIRouter, Depends, Request

from app.auth import require_token
from app.db import db_cursor
from app.rate_limit import limiter
from app.schemas import DictItem, ModelItem

router = APIRouter(
    prefix="/api/v1/dictionaries",
    tags=["dictionaries"],
    dependencies=[Depends(require_token)],
)


def _fetch_simple(table: str) -> list[DictItem]:
    with db_cursor() as cur:
        cur.execute(f"SELECT id, name FROM {table} ORDER BY name")  # noqa: S608  # nosec B608
        return [DictItem(**row) for row in cur.fetchall()]


@router.get("/types", response_model=list[DictItem])
@limiter.limit("60/minute")
def list_types(request: Request) -> list[DictItem]:
    return _fetch_simple("types")


@router.get("/vendors", response_model=list[DictItem])
@limiter.limit("60/minute")
def list_vendors(request: Request) -> list[DictItem]:
    return _fetch_simple("vendors")


@router.get("/statuses", response_model=list[DictItem])
@limiter.limit("60/minute")
def list_statuses(request: Request) -> list[DictItem]:
    return _fetch_simple("statuses")


@router.get("/storage-places", response_model=list[DictItem])
@limiter.limit("60/minute")
def list_storage_places(request: Request) -> list[DictItem]:
    return _fetch_simple("storage_places")


@router.get("/models", response_model=list[ModelItem])
@limiter.limit("60/minute")
def list_models(request: Request) -> list[ModelItem]:
    with db_cursor() as cur:
        cur.execute("SELECT id, name, vendor_id FROM models ORDER BY name")
        return [ModelItem(**row) for row in cur.fetchall()]
