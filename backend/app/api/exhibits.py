"""
POST /api/v1/exhibits — zapis nowego eksponatu + zdjęć do MariaDB `zbiory`.

Port 1:1 z `~/Projekty_software/muzeum-inwentarz/importuj_mariadb.py` — ten sam
lookup_or_insert dla słowników, ten sam zestaw 14 kolumn, te same parametry
preprocessingu zdjęć (1800px JPEG q85).
"""
import base64
import binascii
import logging
import uuid

logger = logging.getLogger(__name__)

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.auth import require_token
from app.db import db_cursor, lookup_or_insert
from app.image_utils import make_detail_image, make_thumbnail, preprocess_for_storage, validate_image_bytes
from app.rate_limit import limiter
from app.schemas import (
    ExhibitCreate,
    ExhibitCreateResponse,
    ExhibitDetail,
    ExhibitListItem,
    ExhibitListResponse,
)

MAX_PHOTO_BYTES = 8 * 1024 * 1024   # per photo, po base64 decode

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
@limiter.limit("20/minute")   # DB write + BLOB storage — expensive
def create_exhibit(request: Request, payload: ExhibitCreate) -> ExhibitCreateResponse:
    processed_photos: list[bytes] = []
    for i, b64 in enumerate(payload.photos_base64):
        try:
            raw = base64.b64decode(b64, validate=True)
        except binascii.Error as e:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                detail=f"Zdjęcie #{i}: niepoprawny base64",
            ) from e
        if len(raw) > MAX_PHOTO_BYTES:
            raise HTTPException(
                status.HTTP_413_CONTENT_TOO_LARGE,
                detail=f"Zdjęcie #{i} przekracza {MAX_PHOTO_BYTES // 1024 // 1024} MB",
            )
        # Waliduj magic bytes — MIME spoofing + polyglot + decomp bomb protection
        validate_image_bytes(raw, label=f"zdjęcie #{i}")
        try:
            processed_photos.append(preprocess_for_storage(raw))
        except Exception as e:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                detail=f"Zdjęcie #{i}: błąd przetwarzania",
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


_SELECT_LIST = """
SELECT
    e.id, e.name,
    v.name AS vendor, m.name AS model
FROM eksponaty e
LEFT JOIN vendors v ON v.id = e.vendor_id
LEFT JOIN models m ON m.id = e.model_id
ORDER BY e.name ASC, e.id ASC
LIMIT %s OFFSET %s
"""


@router.get("/exhibits", response_model=ExhibitListResponse)
@limiter.limit("60/minute")
def list_exhibits(
    request: Request,
    page: int = 1,
    per_page: int = 50,
) -> ExhibitListResponse:
    """Lista eksponatów alfabetycznie + miniatury (~400px) pierwszych zdjęć."""
    if page < 1:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "page musi być >= 1")
    if per_page < 1 or per_page > 100:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "per_page musi być w 1..100")

    offset = (page - 1) * per_page

    with db_cursor() as cur:
        cur.execute("SELECT COUNT(*) AS c FROM eksponaty")
        total_row = cur.fetchone()
        total = int(total_row["c"]) if total_row else 0

        cur.execute(_SELECT_LIST, (per_page, offset))
        rows = cur.fetchall()

        thumbs_by_id: dict[str, str] = {}
        if rows:
            ids = [row["id"] for row in rows]
            placeholders = ",".join(["%s"] * len(ids))
            cur.execute(
                f"""
                SELECT p.eksponat_id, p.photo
                FROM photos p
                INNER JOIN (
                    SELECT eksponat_id, MIN(id) AS first_id
                    FROM photos
                    WHERE eksponat_id IN ({placeholders})
                    GROUP BY eksponat_id
                ) firsts ON p.id = firsts.first_id
                """,  # noqa: S608  (placeholders zbudowane z len(ids), nie z user input)
                ids,
            )
            for prow in cur.fetchall():
                eid = prow["eksponat_id"]
                blob = prow["photo"]
                try:
                    thumbs_by_id[eid] = base64.standard_b64encode(make_thumbnail(blob)).decode("ascii")
                except Exception as e:
                    logger.warning("list_exhibits: thumbnail failed for %s: %s", eid, e)

    results = [
        ExhibitListItem(
            id=row["id"],
            name=row["name"],
            vendor=row["vendor"],
            model=row["model"],
            thumbnail_b64=thumbs_by_id.get(row["id"]),
        )
        for row in rows
    ]

    return ExhibitListResponse(
        results=results,
        total=total,
        page=page,
        per_page=per_page,
        has_more=offset + len(rows) < total,
    )


_SELECT_EXHIBIT = """
SELECT
    e.id, e.name, e.serial_number, e.part_number, e.revision,
    e.production_year, e.description, e.has_original_packaging,
    t.name AS type, v.name AS vendor, m.name AS model,
    s.name AS status, sp.name AS storage_place
FROM eksponaty e
LEFT JOIN types t ON t.id = e.type_id
LEFT JOIN vendors v ON v.id = e.vendor_id
LEFT JOIN models m ON m.id = e.model_id
LEFT JOIN statuses s ON s.id = e.status_id
LEFT JOIN storage_places sp ON sp.id = e.storage_place_id
WHERE e.id = %s
"""


@router.get("/exhibits/{exhibit_id}", response_model=ExhibitDetail)
@limiter.limit("60/minute")
def get_exhibit(request: Request, exhibit_id: str) -> ExhibitDetail:
    """Pełne dane eksponatu + pierwsze zdjęcie (~800px base64) do detail view."""
    with db_cursor() as cur:
        cur.execute(_SELECT_EXHIBIT, (exhibit_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Nie znaleziono eksponatu")

        cur.execute(
            "SELECT photo FROM photos WHERE eksponat_id=%s ORDER BY id",
            (exhibit_id,),
        )
        photo_rows = cur.fetchall()

    photo_b64: str | None = None
    if photo_rows:
        try:
            photo_b64 = base64.standard_b64encode(make_detail_image(photo_rows[0]["photo"])).decode("ascii")
        except Exception as e:
            # Brak zdjęcia nie powinien blokować całego response, ale loguj —
            # ciche except:pass bandit flaguje jako B110 (CWE-703).
            logger.warning("get_exhibit: thumbnail generation failed for %s: %s", exhibit_id, e)

    return ExhibitDetail(
        id=row["id"],
        name=row["name"],
        type=row["type"],
        vendor=row["vendor"],
        model=row["model"],
        serial_number=row["serial_number"],
        part_number=row["part_number"],
        revision=row["revision"],
        production_year=row["production_year"],
        status=row["status"],
        storage_place=row["storage_place"],
        description=row["description"],
        has_original_packaging=bool(row["has_original_packaging"]),
        photo_b64=photo_b64,
        photos_count=len(photo_rows),
    )
