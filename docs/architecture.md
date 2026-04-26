# Architektura — Inwentaryzacja-Mobile

Dokument projektowy. Stan: kwiecień 2026, sole maintainer.

## Trzy warstwy

```
┌─────────────────────────────────────────┐
│  Pixel 10 Pro (Android 15+)             │
│  ┌───────────────────────────────────┐  │
│  │ Qt 6.9 Android apka              │  │
│  │  • QML pages (Welcome, Camera,   │  │
│  │    Edit, Similar, Detail, List)  │  │
│  │  • C++ ApiClient (QNAM)          │  │
│  │  • CameraIntent (JNI bridge)     │  │
│  └────────────┬──────────────────────┘  │
└───────────────┼─────────────────────────┘
                │ HTTPS multipart/JSON
                ▼
┌─────────────────────────────────────────┐
│  Backend FastAPI (Python 3.12)          │
│  ┌───────────────────────────────────┐  │
│  │  /api/v1/identify (Claude vision)│  │
│  │  /api/v1/exhibits (CRUD)         │  │
│  │  /api/v1/similar  (CLIP+LanceDB) │  │
│  │  /api/v1/dictionaries            │  │
│  │  /health                         │  │
│  │                                   │  │
│  │  • slowapi rate limit            │  │
│  │  • Bearer token auth             │  │
│  │  • Pillow MIME+magic+decomp     │  │
│  │  • security headers middleware   │  │
│  └────┬───────────────┬──────────────┘  │
└───────┼───────────────┼─────────────────┘
        │               │
        ▼               ▼
   ┌────────┐      ┌─────────┐
   │ Claude │      │ MariaDB │
   │ Opus   │      │ `zbiory`│
   │ 4.7    │      │  (1870  │
   │(vision)│      │  eksp.) │
   └────────┘      └─────────┘
                        ▲
                        │
                   ┌────┴────┐
                   │ Desktop │
                   │  (Qt    │
                   │ Widgets)│
                   └─────────┘
```

**Wspólna baza** = mobile zapis widoczny w desktopie i odwrotnie (ten sam schemat `eksponaty` + `photos`).

## Apka Qt Android

### Stack
- **Qt 6.9.x Android arm64_v8a** (build z linux-dev Linux LUB macos-dev Apple Silicon)
- **QML 6** (Welcome/Camera/Edit/Similar/Detail/List/Settings pages)
- **C++17** dla ApiClient + CameraIntent + AppSettings
- **JNI bridge** dla Camera Intent (Pixel HDR+/Night Sight, NIE QtMultimedia QCamera)
- **Fusion style** (Material/Basic mają rainbow render bug na Pixel 10 Pro / Android 16)

### Kluczowe klasy

| Klasa | Plik | Rola |
|---|---|---|
| `ApiClient` | `src/ApiClient.cpp` | Async HTTP do backendu, sygnały na każdą operację (identify/save/similar/list/detail/health), uniwersalny request token (Q-05) |
| `AppSettings` | `src/AppSettings.cpp` | URL backendu + Bearer token (sessional na Android, security tier-1.5), cache apiUrl (eliminacja per-request I/O) |
| `CameraIntent` | `src/CameraIntent.cpp` | Singleton JNI wrapper na `MainActivity.launchCamera()`, std::atomic dla thread safety (Camera callback z innego wątku) |
| `MainActivity` | `android/src/.../MainActivity.kt` | Java-side Camera Intent + FileProvider URI + native callback `nativeOnPhotoCaptured(path)` |

### Wzorce architektoniczne (post-audit 2026-04-25)

1. **prepareRequest helper** — auth + timeout + URL boilerplate w 1 miejscu (5 endpointów reuse)
2. **Universal request token (UUID per request)** — każda metoda zwraca rid, sygnały przekazują rid jako 1. arg, QML strona filtruje "to mój request". Eliminuje cross-page leak (apiClient = singleton).
3. **statusText/statusColor pattern** — `property string statusText` + Label binding zamiast imperatywnego `statusLabel.text =`
4. **ListModel cap 500 items** — bez tego 1870 eksp × 30KB thumb = 55MB w pamięci
5. **C++ unique_ptr ownership** dla QFile + QHttpMultiPart, release() po `m_nam->post()`
6. **defense-in-depth `validatePhotoPath`** — canonical path + magic bytes JPEG/PNG przed `QFile::open`

Pełny audit raport: [`audit-2026-04-25.md`](audit-2026-04-25.md)

## Backend FastAPI

### Stack
- **Python 3.12** + venv
- **FastAPI** + uvicorn
- **slowapi** (rate limiting)
- **Pillow** (image validation + preprocessing)
- **PyMySQL** (MariaDB connection)
- **anthropic** (Claude API client)
- **open_clip + lancedb** (CLIP embedding similarity)

### Endpoints

```
POST /api/v1/identify          (multipart 1 photo) → Artefakt JSON
POST /api/v1/exhibits/multipart (multipart photos + form fields) → save + return id
GET  /api/v1/exhibits          (paginated list z thumbnails)
GET  /api/v1/exhibits/{id}     (detail + photos)
POST /api/v1/similar?top_k=N    (multipart 1 photo) → top N similar items
GET  /api/v1/dictionaries/{table}  (types/vendors/models/statuses/storage_places)
GET  /health                   (status backendu, version, DB ok)
```

### Security tier-1.5 (zaaudytowane 2026-04-22)

- `api_token` + `mariadb_password` REQUIRED w config (no defaults, fail-fast on startup)
- `hmac.compare_digest` (timing-safe auth)
- Prod guards: `/docs` off, `/health` minimal (bez stats), DEV_MOCK_IDENTIFY block w produkcji
- Rate limit per endpoint (identify 10/min, exhibits 20/min, similar 30/min)
- Pillow: MIME validate + magic bytes + decomp bomb explicit check + 8 MB photo limit
- Security headers: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, `Permissions-Policy` (no geo/cam/mic/payment)
- Pentest: ZAP baseline 66 PASS / 0 FAIL, testssl grade B (self-signed, prod LE → A+), SQLi fuzz clean, `pip-audit` 0 CVE

## Baza MariaDB `zbiory`

Schemat dziedziczony z desktopa. Kluczowe tabele:

```sql
eksponaty (id UUID, name, type_id, vendor_id, model_id, serial_number,
           part_number, revision, production_year, status_id, storage_place_id,
           description TEXT, value INT, has_original_packaging BOOL)

photos (id UUID, eksponat_id UUID, photo BLOB)

types, vendors, models, statuses, storage_places  -- słowniki, lookup_or_insert pattern
```

**Wspólne z desktopem:** mobile zapisuje przez `lookup_or_insert` na słownikach, desktop czyta z tych samych. Brak duplikatów.

## Multi-device dev setup

Apka + backend dev na 3 maszynach:

| Maszyna | Rola | Backend? | Baza? |
|---|---|---|---|
| **macos-dev** (macOS Apple Silicon, <adres-backendu>) | dev primary | TAK (port 8000) | TAK (MariaDB 12.2.2) |
| **linux-dev** (Linux laptop, <adres-backendu>) | dev secondary, Android build | TAK (port 8000) | TAK (klon przez mysqldump) |
| **serwer** (serwer, <adres-backendu>) | NIE używany dla Inwentaryzacji-Mobile | — | — |

Apka konfigurowana per-maszyna: Settings → URL = `http://<adres-backendu>:8000` (macos-dev) lub `http://<adres-backendu>:8000` (linux-dev).

Klucz API + token bearer per-maszyna w `.env` backendu.

## Roadmap (kwiecień 2026)

### Krótkoterminowo (do wakacji)
- [x] Audit qt-cpp + qt-qml zaliczony (9 PRów P1+P2)
- [x] Sync discipline multi-device (sanity check `git ls-remote` przed pracą)
- [ ] **K14:** Deploy backendu na hosting publiczny (decyzja providera, TLS, domena)
- [ ] **K15:** Google Play Internal Testing track ($25, do 100 testerów)
- [ ] **K16:** "Dopisz opis AI" per eksponat (analogicznie do desktop v1.5)

### Średnioterminowo
- [ ] Android Keystore dla token API (zamiast sessional QSettings)
- [ ] Offline mode (zapis lokalny + sync gdy network)
- [ ] Multi-foto per request (więcej kontekstu dla Claude vision)
- [ ] Multi-language UI (polski/angielski na start, plan zgodny z desktop v1.5)

### Długoterminowo
- [ ] Public Play Store (open testing → production track)
- [ ] iOS port (Qt + nadal sole maintainer = osobny dyskutowany projekt)
- [ ] Statystyki kolekcji w apce (wykresy producent/era/status)

## Powiązane projekty

- **[arekbr/Inwentaryzacja](https://github.com/arekbr/Inwentaryzacja)** (desktop) — Qt Widgets, sole maintainer, ten sam schemat MariaDB
- **muzeum-inwentarz** (offline AI pipeline) — Python batch, wspólny `Artefakt` Pydantic model

## Decyzje historyczne (lessons learned)

- **Fusion style** zamiast Material/Basic — incydent rainbow render bug na Pixel 10 Pro / Android 16 (landmine 11)
- **JNI Camera Intent** zamiast QCamera — Pixel HDR+/Night Sight tylko przez native Intent, QtMultimedia daje plain camera bez przetwarzania
- **Multipart upload** zamiast base64 w JSON — base64 dla 8 MB JPEG = ~25-30 MB transient heap, OOM risk na low-end Android (audit C-D02)
- **Token sessional** (Android) zamiast persistent — security tier-1.5 świadoma decyzja (backup/restore exposure), tier-2 plan: Android Keystore
- **Backend deploy NIE na serwer** — od razu na hosting internetowy żeby apka działała wszędzie z internetem bez VPN
- **Mono-repo** (mobile zawiera `backend/` + `android-app/` + `infra/` + `docs/`) — preferencja "wszystko razem"
