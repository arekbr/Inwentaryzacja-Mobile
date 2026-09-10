# Changelog — Inwentaryzacja-Mobile

Wszystkie istotne zmiany w projekcie. Format: [Keep a Changelog](https://keepachangelog.com/pl/1.1.0/), wersjonowanie [SemVer](https://semver.org/lang/pl/).

## [Unreleased]

### Done
- Audit qt-cpp-review + qt-qml-review zaliczony (raport `docs/audit-2026-04-25.md`)
- 9 PRów P1 + P2 zmergowanych: cleanup architektoniczny w ApiClient, security hardening, UX prompty 401, Q-05 universal request token, ListModel cap, Q-11 statusText pattern, Q-13 deferred do RFC
- Lokalne sync discipline (multi-device): naprawa narrow refspec na lokalnym klonie
- LICENSE MIT, README rozbudowane, CHANGELOG od zera, repo PUBLIC

### TODO
- Deploy backendu na hosting publiczny (K14)
- "Dopisz opis AI" — port flow z desktopowej v1.5 (K16)

---

## [0.2.1] — 2026-09-10 (edge-to-edge)

### Fixed
- **Pasek systemowy znikał po powrocie z aparatu.** Objaw: górny pas czarny, bez zegara
  (Pixel 10 Pro 07.09, odtworzone na emulatorze Android 16 10.09). Przyczyna zmierzona
  przez `adb shell dumpsys window`: okno wracało ze stanem `type=statusBars visible=false`
  — pasek był UKRYTY, a nie „nieodrysowany". Naprawione w warstwie okna
  (`MainActivity.onResume()` → `WindowInsetsControllerCompat.show(systemBars)`), bo systemowego
  zegara nie da się narysować paddingiem w QML.
- **Pasek gestów zasłaniał przyciski na dole stron.** `SafeArea.margins.bottom` = 24 na
  Androidzie 16 nie było obsłużone nigdzie — przyciski „Zrób ponownie"/„Zidentyfikuj" leżały
  pod paskiem nawigacji. Dodane `bottomPadding` na wszystkich pięciu stronach.
- **ToolBar czytał własną safe area**, co karmi pętlę wiązań (padding zmienia geometrię,
  geometria przelicza margines). Zmienione na safe area okna. Podłoga 60 px zostaje: zmierzone
  52 px na emulatorze bez wyspy aparatu, urządzeń z wyspą nie mierzono.

### Świadomie nie zrobione
- **R8** — Qt dostarcza gołe `.jar` bez consumer keep rules, a aparat woła Javę przez JNI po
  nazwie (`launchCamera`, `nativeOnPhotoCaptured`). Bez własnych reguł keep R8 zmiótłby główną
  funkcję apki, cicho i dopiero w release.
- **Wycinanie nieużywanych stylów QtQuick Controls** — zysk zmierzony na 2,82 MB po kompresji
  z 20,65 MB pobierania, a jedyny wspierany mechanizm (`QT_ANDROID_DEPLOYMENT_DEPENDENCIES`)
  wyłącza automatyczne wykrywanie zależności i wymaga ręcznej listy wszystkiego. Styl **Basic
  i tak musi zostać** — Fusion importuje go wprost, a `StackView` istnieje wyłącznie w Basic.

## [0.2.0] — 2026-09-07 (targetSdk 36 / Qt 6.11)

### Changed
- `targetSdkVersion` 35 → **36** (Android 16) — wymóg Google Play dla aktualizacji od 31.08.2026
- `minSdkVersion` 26 → **28** (dolna granica Qt 6.11), `compileSdkVersion` 36
- Toolchain: Qt 6.9.x → **6.11.2** (Qt 6.9 oficjalnie wspiera tylko do API 35); NDK r27c, JDK 21
- Własne `.so` linkowane z `-z max-page-size=16384` (16 KB page size, wymóg Play dla targetSdk ≥ 35)
- `scripts/build-release-aab.sh`: toolchain wykrywany per system (macOS/Linux), hasło ze stdin bez echa
- Manifest phone-only (`largeScreens/xlargeScreens=false`), `versionCode` z `git rev-list --count` (zmiany z 30.04, dotąd niezacommitowane)
- `Qt6::Multimedia` usunięte (nieużywane; pre-built FFmpeg z Qt 6.9 miał 4 KB align)

### Added
- `scripts/verify-aab.sh` — podpis, 16 KB alignment wszystkich `.so`, manifest przez `bundletool`
- `play-assets/`: ikona 512 RGB, feature graphic 1024×500, screenshoty 9:16

### Released
- Google Play, produkcja: v0.1.0 (kod 98) opublikowana 05.05.2026

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
- Dev na dwóch platformach: macOS (Apple Silicon, MariaDB 12.x) + Linux (MariaDB 11.x)

### Pomyłki/lekcje
- **Fusion + Flickable + Android 16 = rainbow render bug** (incydent landmine 11) — workaround: brak Flickable w EditExhibitPage, compact form
- **Qt Surface destroyed po Camera Intent** — workaround: `adb uninstall` between deploys (landmine 11a)
- **Token API plaintext w QSettings** — security tradeoff świadomy dla MVP (tier-2 plan: Android Keystore)
