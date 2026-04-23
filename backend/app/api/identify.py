import logging

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status

from app.auth import require_token
from app.claude_client import identify
from app.config import settings
from app.image_utils import validate_image_bytes
from app.mock_fixtures import mock_identify_response
from app.rate_limit import limiter
from app.schemas import Artefakt

logger = logging.getLogger(__name__)

MAX_IMAGES = 5
MAX_IMAGE_BYTES = 8 * 1024 * 1024   # 8 MB. Było 20 MB. Claude i tak skaluje do 2000px,
                                    # a 5×8 MB = 40 MB RAM per request — znośne.

router = APIRouter(
    prefix="/api/v1",
    tags=["identify"],
    dependencies=[Depends(require_token)],
)


@router.post("/identify", response_model=Artefakt)
@limiter.limit("10/minute")   # Claude Opus = $$$, tight limit per IP
async def identify_endpoint(
    request: Request,
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
    for idx, img in enumerate(images):
        data = await img.read()
        if len(data) > MAX_IMAGE_BYTES:
            raise HTTPException(
                status.HTTP_413_CONTENT_TOO_LARGE,
                detail=f"Zdjęcie #{idx+1} przekracza {MAX_IMAGE_BYTES // 1024 // 1024} MB",
            )
        # Waliduj że to jest faktyczny JPEG/PNG/WEBP/HEIF, nie polyglot
        # z Content-Type-spoofed headerem. Chroni przed atakiem na Pillow.
        validate_image_bytes(data, label=f"zdjęcie #{idx+1}")
        raw_list.append(data)

    try:
        return await identify(raw_list)
    except RuntimeError as e:
        # RuntimeError = config errors (np. brak ANTHROPIC_API_KEY) — logujemy
        # pełny message po stronie serwera, userowi ogólny komunikat.
        logger.error("identify config error: %s", e)
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Błąd konfiguracji serwera",
        ) from e
    except Exception as e:
        # Błędy z Anthropic SDK mogą zawierać fragmenty payloadu (w tym klucza).
        # Loguj pełnego trace po stronie serwera, usera informuj ogólnikowo.
        logger.exception("identify: Claude API failed")
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail="Claude API niedostępne",
        ) from e
