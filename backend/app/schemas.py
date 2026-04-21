"""
Pydantic modele — port 1:1 z `~/Projekty_software/muzeum-inwentarz/inwentarz.py`.

Trzymamy dokładnie ten sam schemat, żeby mobilny backend i offline pipeline
produkowały spójny JSON wchodzący do tabeli `eksponaty`.
"""
from typing import Literal

from pydantic import BaseModel, Field

Typ = Literal[
    "Komputer",
    "Konsola",
    "Monitor",
    "Klawiatura",
    "Mysz",
    "Joystick",
    "Drukarka",
    "Plotter",
    "Stacja dyskietek",
    "Magnetofon",
    "Modem",
    "Kaseta",
    "Dyskietka",
    "Kartridż",
    "Płyta CD/DVD",
    "EPROM",
    "Kabel",
    "Zasilacz",
    "Peryferium",
    "Dokumentacja",
    "Opakowanie",
    "Oprogramowanie",
    "Część elektroniczna",
    "Inne",
]

Status = Literal["Sprawny", "Uszkodzony", "W naprawie", "Niesprawdzony"]

TYPY: list[str] = list(Typ.__args__)  # type: ignore[attr-defined]
STATUSY: list[str] = list(Status.__args__)  # type: ignore[attr-defined]


class Analiza(BaseModel):
    widoczne_oznaczenia: list[str]
    cechy_identyfikacyjne: list[str]
    pewnosc: float = Field(ge=0.0, le=1.0)
    wymaga_weryfikacji: bool
    notatki_dla_kuratora: str
    sugerowane_tagi: list[str]


class Artefakt(BaseModel):
    name: str = Field(description="krótka nazwa eksponatu")
    type: Typ
    vendor: str | None = Field(default=None, description="producent; null jeśli nieznany")
    model: str | None = Field(default=None, description="oznaczenie modelu")
    serial_number: str | None = None
    part_number: str | None = None
    revision: str | None = None
    production_year: int | None = Field(ge=1900, le=2100, default=None)
    status: Status
    description: str
    has_original_packaging: bool
    analiza: Analiza


class DictItem(BaseModel):
    id: str
    name: str


class ModelItem(BaseModel):
    id: str
    name: str
    vendor_id: str | None = None


class ExhibitCreate(BaseModel):
    """
    Payload dla `POST /api/v1/exhibits`.

    Wymagane: name, type, vendor, model, status, storage_place (NOT NULL w bazie).
    Vendor/model, jeśli nie istnieją w słowniku, zostaną dopisane (lookup_or_insert).
    """
    name: str
    type: Typ
    vendor: str
    model: str
    serial_number: str | None = None
    part_number: str | None = None
    revision: str | None = None
    production_year: int | None = Field(ge=1900, le=2100, default=None)
    status: Status
    storage_place: str
    description: str | None = None
    value: int | None = Field(ge=0, default=None)
    has_original_packaging: bool = False
    photos_base64: list[str] = Field(
        default_factory=list,
        description="Lista zdjęć w base64 (JPEG/PNG/HEIC). Każde zostanie zmniejszone do 1800px JPEG q85.",
    )


class ExhibitCreateResponse(BaseModel):
    id: str
    photos_count: int


class SimilarResult(BaseModel):
    exhibit_id: str
    name: str
    vendor: str | None = None
    model: str | None = None
    distance: float = Field(description="L2 distance (0 = identyczne, >1 = różne)")
    thumbnail_b64: str | None = Field(
        default=None,
        description="Miniatura JPEG ~400px base64 (inline, żeby uniknąć drugiego round-trip z auth)",
    )


class SimilarResponse(BaseModel):
    results: list[SimilarResult]
    index_size: int
