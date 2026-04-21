from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth import require_token
from app.db import db_cursor


class DictItem(BaseModel):
    id: str
    name: str


class ModelItem(BaseModel):
    id: str
    name: str
    vendor_id: str | None = None


router = APIRouter(
    prefix="/api/v1/dictionaries",
    tags=["dictionaries"],
    dependencies=[Depends(require_token)],
)


def _fetch_simple(table: str) -> list[DictItem]:
    with db_cursor() as cur:
        cur.execute(f"SELECT id, name FROM {table} ORDER BY name")  # noqa: S608 — table jest whitelisted
        return [DictItem(**row) for row in cur.fetchall()]


@router.get("/types", response_model=list[DictItem])
def list_types() -> list[DictItem]:
    return _fetch_simple("types")


@router.get("/vendors", response_model=list[DictItem])
def list_vendors() -> list[DictItem]:
    return _fetch_simple("vendors")


@router.get("/statuses", response_model=list[DictItem])
def list_statuses() -> list[DictItem]:
    return _fetch_simple("statuses")


@router.get("/storage-places", response_model=list[DictItem])
def list_storage_places() -> list[DictItem]:
    return _fetch_simple("storage_places")


@router.get("/models", response_model=list[ModelItem])
def list_models() -> list[ModelItem]:
    with db_cursor() as cur:
        cur.execute("SELECT id, name, vendor_id FROM models ORDER BY name")
        return [ModelItem(**row) for row in cur.fetchall()]
