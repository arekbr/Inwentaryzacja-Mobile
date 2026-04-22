import base64
import logging

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status

from app.auth import require_token
from app.db import db_cursor
from app.image_utils import make_thumbnail
from app.rate_limit import limiter
from app.schemas import SimilarResponse, SimilarResult
from app.similarity import index_size, search_similar

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/v1",
    tags=["similar"],
    dependencies=[Depends(require_token)],
)


@router.post("/similar", response_model=SimilarResponse)
@limiter.limit("30/minute")   # CLIP tanie ale DB hits + thumbs generation
async def similar_endpoint(
    request: Request,
    image: UploadFile = File(..., description="Zdjęcie JPEG/PNG/HEIC"),
    top_k: int = Query(10, ge=1, le=50, description="Ile najbliższych zwrócić"),
) -> SimilarResponse:
    raw = await image.read()
    if not raw:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Puste zdjęcie")

    try:
        matches = search_similar(raw, top_k=top_k)
    except Exception as e:
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            f"Błąd similarity search: {e}",
        ) from e

    # Dociągnij miniatury pierwszych zdjęć dla każdego wyniku (jeden SELECT IN).
    thumbs_by_id: dict[str, str] = {}
    if matches:
        ids = [m["exhibit_id"] for m in matches]
        placeholders = ",".join(["%s"] * len(ids))
        with db_cursor() as cur:
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
                """,
                ids,
            )
            for row in cur.fetchall():
                eid = row["eksponat_id"]
                blob = row["photo"]
                try:
                    thumbs_by_id[eid] = base64.standard_b64encode(make_thumbnail(blob)).decode("ascii")
                except Exception as e:
                    logger.warning("Thumbnail failed for %s: %s", eid, e)

    results = [
        SimilarResult(
            exhibit_id=m["exhibit_id"],
            name=m["name"],
            vendor=m.get("vendor"),
            model=m.get("model"),
            distance=float(m["_distance"]),
            thumbnail_b64=thumbs_by_id.get(m["exhibit_id"]),
        )
        for m in matches
    ]

    return SimilarResponse(results=results, index_size=index_size())
