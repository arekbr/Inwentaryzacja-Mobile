"""
Claude API — identyfikacja eksponatu. Port 1:1 z `inwentarz.py`.

Używa Claude Opus 4.7 (domyślnie) + structured output przez `messages.parse`.
System prompt ma `cache_control: ephemeral` — prompt caching, ~10× tańszy
drugi i kolejne calls w 5-minutowym oknie.
"""
from functools import lru_cache

from anthropic import AsyncAnthropic

from app.config import settings
from app.image_utils import encode_image_to_base64
from app.schemas import Artefakt, STATUSY, TYPY

MODEL = "claude-opus-4-7"
MAX_TOKENS = 4096

SYSTEM_PROMPT = f"""Jesteś kuratorem muzeum retro komputerów i elektroniki użytkowej \
z trzydziestoletnim doświadczeniem. Specjalizujesz się w sprzęcie z lat 1975–2005: \
mikrokomputery (Commodore, Atari, Sinclair, Amstrad, Apple, IBM PC i klony, Amiga), \
konsole, nośniki danych (kasety, dyskietki, EPROM-y), peryferia, dokumentacja \
oraz polska i wschodnioeuropejska elektronika (Elwro, Mera, Meritum, Unipolbrit).

Twoje zadanie: przeanalizować zdjęcie eksponatu i wygenerować wpis zgodny ze \
schematem bazy `Inwentaryzacja` (https://github.com/arekbr/Inwentaryzacja) — \
tabela `eksponaty` z słownikami `types`, `vendors`, `models`, `statuses`.

WAŻNE: Jeżeli w jednej wiadomości otrzymasz więcej niż jedno zdjęcie, traktuj je \
jako zdjęcia TEGO SAMEGO eksponatu z różnych stron (przód, tył, boki, szczegóły, \
wnętrze, naklejki). Wygeneruj JEDEN wpis, łącząc informacje ze wszystkich zdjęć — \
np. model/logo widać z przodu, a numer seryjny i rok z tyłu.

Mapowanie pól wyjściowych na bazę:
- `name` — krótka nazwa eksponatu do listy (np. "Commodore 64", "Magnetofon Datassette 1530")
- `type` — kategoria ze słownika: {', '.join(TYPY)}
- `vendor` — producent (wolny tekst; importer dopisze do słownika jeśli nowy)
- `model` — oznaczenie modelu producenta (np. "C64", "800XL", "Spectrum 48K")
- `serial_number` — numer seryjny z tabliczki; null jeśli niewidoczny
- `part_number` — numer katalogowy/PN jeśli widoczny
- `revision` — rewizja płyty lub obudowy, np. "Assy 250466", "Issue 3B", "short board"
- `production_year` — jedna liczba 1900–2100; null jeśli nieznana
- `status` — {', '.join(STATUSY)}. Na podstawie samego zdjęcia najczęściej \
"Niesprawdzony", chyba że widać wyraźne uszkodzenia → "Uszkodzony"
- `description` — 2–4 zdania: co to jest, co charakterystyczne, dla kogo/do czego
- `has_original_packaging` — czy na zdjęciu widać oryginalne pudełko/opakowanie

Pole `analiza` (pomocnicze dla kuratora, nie trafia bezpośrednio do SQL):
- `widoczne_oznaczenia` — dosłowny odczyt napisów z tabliczek, naklejek, nadruków
- `cechy_identyfikacyjne` — co posłużyło do identyfikacji (tabliczka, układ klawiszy…)
- `pewnosc` — 0.0–1.0
- `wymaga_weryfikacji` — true gdy pewność < 0.7 lub widać coś nietypowego
- `notatki_dla_kuratora` — co warto sprawdzić ręcznie (otworzyć, zmierzyć, przetestować)
- `sugerowane_tagi` — tagi pomocnicze: '8bit', 'europa', 'PAL', '1982', 'klon'

Zasady:
- Jeśli czegoś nie widać/nie jesteś pewien — null i niższa `pewnosc`. Nie zgaduj.
- Nazwy producentów pełne, historyczne ("Commodore Business Machines" → "Commodore").
- Pisz po polsku, zwięźle, konkretnie. Bez lania wody."""


@lru_cache(maxsize=1)
def _get_client() -> AsyncAnthropic:
    if not settings.anthropic_api_key:
        raise RuntimeError("ANTHROPIC_API_KEY nie ustawione — sprawdź .env")
    return AsyncAnthropic(api_key=settings.anthropic_api_key)


async def identify(images_raw: list[bytes]) -> Artefakt:
    """Wysyła 1..N zdjęć TEGO SAMEGO eksponatu do Claude, zwraca strukturalny Artefakt."""
    if not images_raw:
        raise ValueError("Brak zdjęć do identyfikacji")

    content_blocks: list[dict] = []
    for raw in images_raw:
        data, media_type = encode_image_to_base64(raw)
        content_blocks.append(
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": data,
                },
            }
        )

    if len(images_raw) == 1:
        instrukcja = "Zidentyfikuj eksponat ze zdjęcia i wygeneruj wpis inwentarzowy."
    else:
        instrukcja = (
            f"Otrzymujesz {len(images_raw)} zdjęć TEGO SAMEGO eksponatu z różnych stron. "
            "Połącz informacje ze wszystkich zdjęć w jeden wpis inwentarzowy — "
            "np. model/logo z przodu, numer seryjny i rok z tyłu."
        )
    content_blocks.append({"type": "text", "text": instrukcja})

    response = await _get_client().messages.parse(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=[
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        messages=[{"role": "user", "content": content_blocks}],
        output_format=Artefakt,
    )
    return response.parsed_output
