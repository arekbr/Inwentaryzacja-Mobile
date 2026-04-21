from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status

from app.auth import require_token
from app.schemas import SimilarResponse, SimilarResult
from app.similarity import index_size, search_similar

router = APIRouter(
    prefix="/api/v1",
    tags=["similar"],
    dependencies=[Depends(require_token)],
)


@router.post("/similar", response_model=SimilarResponse)
async def similar_endpoint(
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

    results = [
        SimilarResult(
            exhibit_id=m["exhibit_id"],
            name=m["name"],
            vendor=m.get("vendor"),
            model=m.get("model"),
            distance=float(m["_distance"]),
        )
        for m in matches
    ]

    return SimilarResponse(results=results, index_size=index_size())
