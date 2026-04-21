"""
POST /api/v1/exhibits — zapis nowego eksponatu + zdjęć do MariaDB `zbiory`.

Port 1:1 z `~/Projekty_software/muzeum-inwentarz/importuj_mariadb.py` — ten sam
lookup_or_insert dla słowników, ten sam zestaw 14 kolumn, te same parametry
preprocessingu zdjęć (1800px JPEG q85).
"""
import base64
import binascii
import uuid

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import require_token
from app.db import db_cursor, lookup_or_insert
from app.image_utils import preprocess_for_storage
from app.schemas import ExhibitCreate, ExhibitCreateResponse

router = APIRouter(
    prefix="/api/v1",
    tags=["exhibits"],
    dependencies=[Depends(require_token)],
)


_INSERT_EKSPONAT = """
INSERT INTO eksponaty (
    id, name, type_id, vendor_id, model_id,
    serial_number, part_number, revision, production_year,
    status_id, storage_place_id, description, value,
    has_original_packaging
) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
"""

_INSERT_PHOTO = "INSERT INTO photos (id, eksponat_id, photo) VALUES (%s, %s, %s)"


@router.post("/exhibits", response_model=ExhibitCreateResponse, status_code=status.HTTP_201_CREATED)
def create_exhibit(payload: ExhibitCreate) -> ExhibitCreateResponse:
    processed_photos: list[bytes] = []
    for i, b64 in enumerate(payload.photos_base64):
        try:
            raw = base64.b64decode(b64, validate=True)
        except binascii.Error as e:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                detail=f"Zdjęcie #{i}: niepoprawny base64 ({e})",
            ) from e
        try:
            processed_photos.append(preprocess_for_storage(raw))
        except Exception as e:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                detail=f"Zdjęcie #{i}: błąd preprocessingu ({e})",
            ) from e

    eksponat_id = str(uuid.uuid4())

    with db_cursor() as cur:
        type_id = lookup_or_insert(cur, "types", payload.type)
        vendor_id = lookup_or_insert(cur, "vendors", payload.vendor)
        model_id = lookup_or_insert(cur, "models", payload.model, {"vendor_id": vendor_id})
        status_id = lookup_or_insert(cur, "statuses", payload.status)
        storage_id = lookup_or_insert(cur, "storage_places", payload.storage_place)

        cur.execute(
            _INSERT_EKSPONAT,
            (
                eksponat_id,
                payload.name,
                type_id,
                vendor_id,
                model_id,
                payload.serial_number,
                payload.part_number,
                payload.revision,
                payload.production_year,
                status_id,
                storage_id,
                payload.description,
                payload.value,
                1 if payload.has_original_packaging else 0,
            ),
        )

        for photo_bytes in processed_photos:
            cur.execute(
                _INSERT_PHOTO,
                (str(uuid.uuid4()), eksponat_id, photo_bytes),
            )

    return ExhibitCreateResponse(id=eksponat_id, photos_count=len(processed_photos))
