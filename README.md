# Inwentaryzacja-Mobile

Mobilna wersja [arekbr/Inwentaryzacja](https://github.com/arekbr/Inwentaryzacja) — Qt Android apka do katalogowania eksponatów muzeum retro-computingu w terenie (zdjęcie → AI identyfikacja → zapis do bazy).

## Architektura

```
[Qt Android apka]  ──WireGuard + HTTPS──▶  [FastAPI na serwer]  ──▶  [MariaDB `zbiory`]
                                                    │
                                                    ├─ Claude Opus 4.7 (identyfikacja)
                                                    └─ CLIP + LanceDB (similarity search)
```

- **Android apka** robi zdjęcie, wysyła do backendu, dostaje JSON z identyfikacją LUB listę podobnych eksponatów z bazy.
- **Backend (FastAPI)** orchestruje: wywołuje Claude API, oblicza CLIP embeddingi, szuka podobnych, zapisuje do MariaDB.
- **Baza** to ta sama `zbiory` co desktop [arekbr/Inwentaryzacja](https://github.com/arekbr/Inwentaryzacja) — zmiany z mobile widoczne w desktop i odwrotnie.

Pełna dyskusja decyzji: [`docs/architecture.md`](docs/architecture.md) (WIP).

## Status

**Early WIP (kwiecień 2026).** Budowa od zera, kroczkami.

## Roadmap

### Backend (priorytet)
- [ ] Szkielet FastAPI + config + venv
- [ ] `POST /api/v1/identify` — Opus 4.7, port logiki z `inwentarz.py`
- [ ] `GET /api/v1/dictionaries/{types,vendors,models,statuses,storage_places}` — dropdowny dla apki
- [ ] `POST /api/v1/exhibits` — zapis do MariaDB (tabele `eksponaty` + `photos`)
- [ ] `POST /api/v1/similar` — CLIP embedding + LanceDB similarity search
- [ ] Pre-computacja embeddingów dla istniejących ~1870 eksponatów (batch, raz)
- [ ] Bearer token auth
- [ ] Deployment na serwer (systemd)

### Apka Qt Android
- [ ] Szkielet Qt 6.8 + QML
- [ ] Kamera → zrób foto
- [ ] Flow: foto → "Zidentyfikuj" → wyniki → edytuj → zapis
- [ ] Flow: foto → "Znajdź podobne" → galeria miniatur
- [ ] Ekrany: Camera, Preview, EditExhibit, SimilarResults, Settings
- [ ] Signing key + AAB build
- [ ] Google Play Internal Testing track ($25 setup)

## Kontekst

- Desktop wersja: https://github.com/arekbr/Inwentaryzacja (C++/Qt 6, CMake)
- Python AI pipeline offline: `~/Projekty_software/muzeum-inwentarz/` (wzbogacanie istniejących opisów)
- Backend mobilny reużywa dokładnie ten sam model JSON `Artefakt` (Pydantic) co `inwentarz.py`

## Licencja

Internal project — brak publicznej licencji.
