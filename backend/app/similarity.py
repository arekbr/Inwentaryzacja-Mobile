"""
Similarity search oparty o CLIP embeddings + LanceDB.

- Model CLIP (domyślnie ViT-B-32/openai) ładowany raz, lazy, przy pierwszym użyciu
- Embeddingi trzymane w LanceDB (file-based vector store w `data/lancedb/`)
- Apple Silicon: MPS (GPU), CUDA jeśli dostępne, inaczej CPU

Graceful degradation: jeśli torch/open_clip/lancedb nie załadują się przy
starcie (np. mismatch wersji torch/torchvision w kontenerze), `/similar`
będzie zwracać 503, ale reszta backendu startuje normalnie.
"""
from __future__ import annotations

import io
import logging
from functools import lru_cache
from pathlib import Path

from PIL import Image

from app.config import settings

logger = logging.getLogger(__name__)

# Lazy import — jeśli importy zawiodą, zapamiętujemy error i zwracamy go
# z każdego call'a. Backend startuje niezależnie od stanu CLIP stacka.
_IMPORT_ERROR: str | None = None
try:
    import lancedb
    import numpy as np
    import open_clip
    import torch
except Exception as e:    # pragma: no cover — env-dependent
    _IMPORT_ERROR = f"{type(e).__name__}: {e}"
    logger.warning("similarity: stack nie załadowany — /similar zwróci 503. %s", _IMPORT_ERROR)

TABLE_NAME = "exhibits"


def _raise_if_unavailable() -> None:
    if _IMPORT_ERROR is not None:
        from fastapi import HTTPException, status
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Similarity search niedostępny: {_IMPORT_ERROR}",
        )


@lru_cache(maxsize=1)
def _device():
    _raise_if_unavailable()
    if torch.backends.mps.is_available():
        return torch.device("mps")
    if torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")


@lru_cache(maxsize=1)
def _load_model():
    """Lazy load: dopiero przy pierwszym wywołaniu embed_image."""
    _raise_if_unavailable()
    model, _, preprocess = open_clip.create_model_and_transforms(
        settings.clip_model,
        pretrained=settings.clip_pretrained,
    )
    model.eval()
    model.to(_device())
    return model, preprocess


def embed_image(raw_bytes: bytes):
    """
    Zwraca L2-znormalizowany CLIP embedding (float32) dla zdjęcia.
    ViT-B-32 → 512-wymiarowy wektor.
    """
    _raise_if_unavailable()
    model, preprocess = _load_model()
    img = Image.open(io.BytesIO(raw_bytes))
    if img.mode != "RGB":
        img = img.convert("RGB")

    tensor = preprocess(img).unsqueeze(0).to(_device())
    with torch.no_grad():
        features = model.encode_image(tensor)
        features = features / features.norm(dim=-1, keepdim=True)

    return features.cpu().numpy().astype(np.float32).squeeze()


@lru_cache(maxsize=1)
def _get_db():
    _raise_if_unavailable()
    path = Path(settings.lancedb_path)
    path.mkdir(parents=True, exist_ok=True)
    return lancedb.connect(str(path))


def _get_table():
    _raise_if_unavailable()
    db = _get_db()
    if TABLE_NAME not in db.list_tables().tables:
        return None
    return db.open_table(TABLE_NAME)


def search_similar(raw_bytes: bytes, top_k: int = 10) -> list[dict]:
    """
    Top-K najbliższych eksponatów do zdjęcia (L2 cosine przez znormalizowane wektory).
    Zwraca listę dictów: exhibit_id, name, vendor, model, _distance.
    Pusta lista jeśli indeks nie istnieje.
    """
    _raise_if_unavailable()
    tbl = _get_table()
    if tbl is None:
        return []

    query_vec = embed_image(raw_bytes)
    return tbl.search(query_vec).limit(top_k).to_list()


def index_exists() -> bool:
    if _IMPORT_ERROR is not None:
        return False
    return _get_table() is not None


def index_size() -> int:
    if _IMPORT_ERROR is not None:
        return 0
    tbl = _get_table()
    return tbl.count_rows() if tbl else 0
