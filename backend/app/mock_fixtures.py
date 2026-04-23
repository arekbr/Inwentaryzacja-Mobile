"""
Mock odpowiedzi dla trybu dev (DEV_MOCK_IDENTIFY=true).

Po co: user płaci realne $ za każde wywołanie Claude Opus (vision + 2000px JPEG).
W trybie dev testujemy UI wielokrotnie przez ten sam eksponat — cached response
jest identyczny strukturalnie z realnym, po prostu nie wali do Anthropic.
"""
from app.schemas import Analiza, Artefakt


def mock_identify_response() -> Artefakt:
    """Mockowany wynik dla klawiatury Amiga-stylowej (kalibrowany przez testy live)."""
    return Artefakt(
        name="Klawiatura Amiga (mock)",
        type="Klawiatura",
        vendor="Commodore",
        model="Amiga 2000/3000",
        serial_number=None,
        part_number=None,
        revision=None,
        production_year=1989,
        status="Niesprawdzony",
        description=(
            "Klawiatura w stylu Amiga z charakterystycznym układem klawiszy i "
            "beżowo-szarym kolorem obudowy. **[MOCK — tryb dev, nie wysłano do AI]**"
        ),
        has_original_packaging=False,
        analiza=Analiza(
            widoczne_oznaczenia=[],
            cechy_identyfikacyjne=[
                "układ klawiszy Amiga",
                "beżowa obudowa",
                "stylizacja lat 80/90",
            ],
            pewnosc=0.45,
            wymaga_weryfikacji=True,
            notatki_dla_kuratora="MOCK — odpowiedź wygenerowana lokalnie, bez wywołania Claude API.",
            sugerowane_tagi=["retro", "commodore", "amiga", "klawiatura"],
        ),
    )
