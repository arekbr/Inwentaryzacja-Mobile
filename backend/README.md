# Backend — FastAPI

Backend dla mobilnej apki Qt Android. Udostępnia endpointy identify/similar/exhibits ponad bazą MariaDB `zbiory` (wspólną z desktopem Inwentaryzacji).

## Setup lokalny

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# edytuj .env — wpisz ANTHROPIC_API_KEY, API_TOKEN itp.
uvicorn app.main:app --reload
```

Sprawdzenie:

```bash
curl http://127.0.0.1:8000/health
# {"status":"ok","version":"0.0.1","database":"zbiory"}
```

Interaktywna dokumentacja: http://127.0.0.1:8000/docs (Swagger UI generowany automatycznie).

## Struktura

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py       # FastAPI app + routery
│   └── config.py     # Settings (pydantic-settings, .env)
├── requirements.txt
├── .env.example
└── README.md
```

## Roadmap endpointów

- [x] `GET /health` — liveness probe
- [ ] `GET /api/v1/dictionaries/{types,vendors,models,statuses,storage-places}` — dropdowny dla apki
- [ ] `POST /api/v1/identify` — JPEG → Claude Opus 4.7 → JSON `Artefakt` (format 1:1 z `inwentarz.py`)
- [ ] `POST /api/v1/exhibits` — zapis nowego rekordu do `eksponaty` + `photos`
- [ ] `POST /api/v1/similar` — CLIP embedding + LanceDB top-10 similarity
- [ ] Batch: pre-computacja embeddingów dla istniejących ~1870 eksponatów

## Deployment (docelowo)

Systemd service na debianJD, uvicorn za WireGuardem — bez public IP. Docker-compose w `infra/` (będzie).
