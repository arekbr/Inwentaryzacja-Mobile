import logging

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.auth import require_token
from app.claude_client import identify
from app.config import settings
from app.mock_fixtures import mock_identify_response
from app.schemas import Artefakt

logger = logging.getLogger(__name__)

MAX_IMAGES = 5
MAX_IMAGE_BYTES = 20 * 1024 * 1024  # 20 MB — Claude API i tak potem skaluje do 2000px

router = APIRouter(
    prefix="/api/v1",
    tags=["identify"],
    dependencies=[Depends(require_token)],
)


@router.post("/identify", response_model=Artefakt)
async def identify_endpoint(
    images: list[UploadFile] = File(..., description="1-5 zdjęć tego samego eksponatu"),
) -> Artefakt:
    if not 1 <= len(images) <= MAX_IMAGES:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail=f"Wymagane 1-{MAX_IMAGES} zdjęć, otrzymano {len(images)}",
        )

    # DEV: mockowana odpowiedź bez wołania Anthropic (oszczędza $ podczas iteracji UI).
    # Czytamy bytes żeby URL form-data nie trafiało otwartego stream'a do GC-a.
    if settings.dev_mock_identify:
        for img in images:
            await img.read()
        logger.warning("[MOCK] /identify — zwracam cached response (DEV_MOCK_IDENTIFY=true)")
        return mock_identify_response()

    raw_list: list[bytes] = []
    for img in images:
        data = await img.read()
        if len(data) > MAX_IMAGE_BYTES:
            raise HTTPException(
                status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Zdjęcie {img.filename} przekracza {MAX_IMAGE_BYTES // 1024 // 1024} MB",
            )
        raw_list.append(data)

    try:
        return await identify(raw_list)
    except RuntimeError as e:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail=f"Claude API: {e}",
        ) from e
