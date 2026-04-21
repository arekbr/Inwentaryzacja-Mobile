"""
Preprocessing zdjęć przed wysłaniem do Claude API.
Port 1:1 z `inwentarz.py:zakoduj_obraz()` — te same stałe MAX_WYMIAR/JPEG_JAKOSC,
żeby zachować jednakowe rozmiary i jakość co offline pipeline.
"""
import base64
import io

from PIL import Image, ImageOps

MAX_WYMIAR = 2000  # px, max dłuższego boku dla /identify (wysyłka do Claude)
JPEG_JAKOSC = 88

STORAGE_MAX_PX = 1800  # zgodnie z zapisz.py/importuj_mariadb.py — zmniejszenie do bazy
STORAGE_JPEG_QUALITY = 85


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
