# Changelog — Inwentaryzacja-Mobile

Wszystkie istotne zmiany w projekcie. Format: [Keep a Changelog](https://keepachangelog.com/pl/1.1.0/), wersjonowanie [SemVer](https://semver.org/lang/pl/).

## [Unreleased]

### Done
- Audit qt-cpp-review + qt-qml-review zaliczony (raport `docs/audit-2026-04-25.md`)
- 9 PRów P1 + P2 zmergowanych: cleanup architektoniczny w ApiClient, security hardening, UX prompty 401, Q-05 universal request token, ListModel cap, Q-11 statusText pattern, Q-13 deferred do RFC
- Lokalne sync discipline (multi-device): `feedback_git_sync_discipline.md` + naprawa narrow refspec na linux-dev
- LICENSE MIT, README rozbudowane, CHANGELOG od zera, repo PUBLIC

### TODO
- Deploy backendu na hosting publiczny (K14)
- AAB + Google Play Internal Testing (5 testerów, K15)
- "Dopisz opis AI" — port flow z desktopowej v1.5 (K16)

---

## [0.0.6] — 2026-04-22 (security tier-1.5 pentest)

### Added
- `infra/prod-sim/` — stack Docker z Caddy TLS reverse proxy + backend ENV=production + MariaDB
- Pentest narzędzia zainstalowane: trufflehog, bandit, semgrep, testssl, sqlmap, hey
- Decomp bomb gap fix — explicit Pillow check przed `verify()` (Pillow `MAX_IMAGE_PIXELS` zwraca tylko Warning, nie Error)
- Similarity graceful degradation — startup nie crashuje gdy CLIP/LanceDB stack pada (503 zamiast crash)
- ZAP baseline scan: 66 PASS / 0 FAIL
- testssl grade B (self-signed; prod LE → A+)

### Validated
- Walidacja formatów: JPEG/PNG/WEBP/HEIF ✓, GIF/TIFF/SVG-XSS/HTML/ZIP/empty ✗
- SAST whitelist `_ALLOWED_LOOKUP_TABLES` w db.py
- SQLi fuzz 8 payloadów = wszystkie text (no injection)
- Rate limit atomic pod 50 concurrent
- `pip-audit` czysto — 0 CVE w zależnościach

## [0.0.5] — 2026-04-22 (security tier-1)

### Added
- `api_token` + `mariadb_password` required w config (no defaults)
- `hmac.compare_digest` auth (timing-safe)
- Prod guards: `/docs` off, `/health` minimal, DEV_MOCK_IDENTIFY block w produkcji
- Rate limit slowapi: identify 10/min, exhibits 20/min, similar 30/min
- Pillow MIME validate + decomposition bomb check + 8 MB photo limit
- Security headers middleware: nosniff, frame-deny, no-referrer, permissions-policy

### Changed
- `.env` rozbudowany o `ENVIRONMENT=development|production`

## [0.0.4] — 2026-04-22 (Welcome panel + UX)

### Added
- Welcome screen z auto-refresh stanu backendu (15s ping)
- BusyIndicator spinners przy wszystkich async calls
- QNAM transferTimeout per endpoint (5s health, 20s similar, 30s save, 45s identify)
- `formatNetworkError` po polsku (mapping QNetworkReply::NetworkError → user message)

## [0.0.3] — 2026-04-22 (przeglądanie bazy + szczegóły)

### Added
- ExhibitListPage (lista alfabetyczna z paginacją, lazy thumbnails 800px base64)
- ExhibitDetailPage (markdown render description + meta + photo)
- `GET /api/v1/exhibits` (paginated) + `GET /api/v1/exhibits/{id}` (detail z thumbnails)

## [0.0.2] — 2026-04-21 (similar + edit + save flow)

### Added
- SimilarPage (Camera Intent → CLIP search → top 5 z miniaturami → tap → Detail)
- EditExhibitPage (compact form bez Flickable — landmine Fusion+Android16+Flickable)
- POST `/api/v1/similar?top_k=N` (CLIP embedding + LanceDB cosine + inline thumbnails 400px)
- POST `/api/v1/exhibits` (zapis + lookup_or_insert dla type/vendor/model/status/storage)

## [0.0.1] — 2026-04-21 (foundation)

### Added
- Szkielet Qt 6.9 Android (CMake + qt-cmake wrapper)
- Backend FastAPI + venv + config + dictionaries endpoint
- Camera Intent przez JNI (Pixel HDR+/Night Sight, NIE QtMultimedia QCamera)
- POST `/api/v1/identify` (Claude Opus 4.7 + DEV_MOCK fallback)
- Schemat MariaDB `zbiory` (wspólny z desktop arekbr/Inwentaryzacja)
- Klon bazy desktop → mobile (mysqldump 977 MB import, 1870 eksponatów)
- Dwa device dev: macos-dev (macOS Apple Silicon, MariaDB 12.2.2) + linux-dev (Linux laptop, MariaDB 11.8.6)

### Pomyłki/lekcje
- **Fusion + Flickable + Android 16 = rainbow render bug** (incydent landmine 11) — workaround: brak Flickable w EditExhibitPage, compact form
- **Qt Surface destroyed po Camera Intent** — workaround: `adb uninstall` between deploys (landmine 11a)
- **Token API plaintext w QSettings** — security tradeoff świadomy dla MVP (tier-2 plan: Android Keystore)
