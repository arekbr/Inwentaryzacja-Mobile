"""
Preprocessing zdjęć przed wysłaniem do Claude API.
Port 1:1 z `inwentarz.py:zakoduj_obraz()` — te same stałe MAX_WYMIAR/JPEG_JAKOSC,
żeby zachować jednakowe rozmiary i jakość co offline pipeline.
"""
import base64
import io

from fastapi import HTTPException, status
from PIL import Image, ImageOps

# Decompression bomb protection: Pillow domyślnie ostrzega gdy pixel count >
# 89M, ale dalej dekoduje. Zaostrzamy limit: 50M pixels (~7000×7000) —
# dużo więcej niż każde realne zdjęcie ale blokuje złośliwe JPEGy
# które pobudzają się do 40000×40000.
Image.MAX_IMAGE_PIXELS = 50_000_000

# Formaty które akceptujemy po inspekcji magic bytes (nie Content-Type headera
# z klienta — ten jest trusted). Pillow `Image.verify()` sam to sprawdza.
ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP", "HEIF", "HEIC"}

MAX_WYMIAR = 2000  # px, max dłuższego boku dla /identify (wysyłka do Claude)
JPEG_JAKOSC = 88


def validate_image_bytes(raw: bytes, label: str = "image") -> None:
    """
    Waliduje, że `raw` to prawdziwe JPEG/PNG/WEBP/HEIF. Rzuca HTTPException 400
    jeśli nie — chroni przed polyglot upload (SVG, HTML, ZIP) które atakujący
    wrzuca udając image/jpeg w Content-Type.

    Używa Image.verify() które dekoduje nagłówek bez pełnego pixel decode —
    szybkie, bezpieczne. Explicit pixel count check zapobiega decompression bomb
    (Pillow `MAX_IMAGE_PIXELS` emituje tylko `DecompressionBombWarning`, nie Error,
    dla rozmiarów między MAX a 2×MAX — fuzz 2026-04-23 wyłapał ten gap).
    """
    if not raw:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"{label}: pusta zawartość")
    try:
        with Image.open(io.BytesIO(raw)) as img:
            # Check pixel count BEFORE verify — decompression bomb protection.
            # Pillow WARN only fires dla rozmiarów > MAX, ale nie raise. Musimy
            # explicit check + reject. Limit jest hard — atakujący nie może
            # wysłać 50M+ pix nawet gdy bytes są małe (np. JPEG compression).
            w, h = img.size
            if w * h > Image.MAX_IMAGE_PIXELS:
                raise HTTPException(
                    status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    f"{label}: decompression bomb — {w}×{h} = {w*h/1e6:.0f}M pixeli > limit {Image.MAX_IMAGE_PIXELS/1e6:.0f}M",
                )
            img.verify()
            fmt = img.format
    except HTTPException:
        raise   # don't wrap our own 413 bomb response
    except Image.DecompressionBombError as e:
        raise HTTPException(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            f"{label}: decompression bomb error",
        ) from e
    except Exception as e:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"{label}: niepoprawny obraz ({e})",
        ) from e

    if fmt not in ALLOWED_FORMATS:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"{label}: format {fmt} niedozwolony. Akceptujemy {sorted(ALLOWED_FORMATS)}",
        )

STORAGE_MAX_PX = 1800  # zgodnie z zapisz.py/importuj_mariadb.py — zmniejszenie do bazy
STORAGE_JPEG_QUALITY = 85

THUMBNAIL_MAX_PX = 400  # miniatury dla listy wyników similarity (mobile)
THUMBNAIL_JPEG_QUALITY = 80

DETAIL_MAX_PX = 800     # pełne zdjęcie dla widoku szczegółów (mobile)
DETAIL_JPEG_QUALITY = 82


def _resize_jpeg(raw: bytes, max_px: int, quality: int) -> bytes:
    img = Image.open(io.BytesIO(raw))
    img = ImageOps.exif_transpose(img)
    if img.mode != "RGB":
        img = img.convert("RGB")
    img.thumbnail((max_px, max_px), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=quality, optimize=True)
    return buf.getvalue()


def make_thumbnail(raw: bytes) -> bytes:
    """Miniaturka JPEG ~400px dla listy wyników similarity na mobile."""
    return _resize_jpeg(raw, THUMBNAIL_MAX_PX, THUMBNAIL_JPEG_QUALITY)


def make_detail_image(raw: bytes) -> bytes:
    """Zdjęcie JPEG ~800px do widoku szczegółów eksponatu na mobile."""
    return _resize_jpeg(raw, DETAIL_MAX_PX, DETAIL_JPEG_QUALITY)


def preprocess_for_storage(raw: bytes) -> bytes:
    """
    Przygotowanie bajtów do zapisu w tabeli `photos` (BLOB).
    Port 1:1 z `importuj_mariadb.py::zmniejsz_zdjecie()` — 1800px, JPEG q85,
    EXIF transpose, konwersja do RGB.
    """
    img = Image.open(io.BytesIO(raw))
    img = ImageOps.exif_transpose(img)

    if img.mode != "RGB":
        img = img.convert("RGB")

    if max(img.size) > STORAGE_MAX_PX:
        img.thumbnail((STORAGE_MAX_PX, STORAGE_MAX_PX), Image.Resampling.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=STORAGE_JPEG_QUALITY, optimize=True)
    return buf.getvalue()


def encode_image_to_base64(raw: bytes) -> tuple[str, str]:
    """
    Przyjmuje surowe bajty zdjęcia (JPEG/PNG/HEIC z apki), zwraca (base64_string, media_type).
    - EXIF orientation respektowany
    - Konwersja do RGB
    - Skalowanie do MAX_WYMIAR jeśli większe
    - Zawsze kodowanie jako JPEG (mniejszy rozmiar niż PNG przy zdjęciach)
    """
    img = Image.open(io.BytesIO(raw))
    img = ImageOps.exif_transpose(img)

    if img.mode != "RGB":
        img = img.convert("RGB")

    if max(img.size) > MAX_WYMIAR:
        img.thumbnail((MAX_WYMIAR, MAX_WYMIAR), Image.Resampling.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=JPEG_JAKOSC, optimize=True)
    return base64.standard_b64encode(buf.getvalue()).decode("utf-8"), "image/jpeg"
