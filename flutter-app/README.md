# Inwentaryzacja Mobile (Flutter)

iOS klient do muzealnej inwentaryzacji retro-komputerów. Zdjęcie eksponatu →
identyfikacja AI (Claude Opus) → edycja → zapis do bazy + wyszukiwanie
podobnych po obrazie (CLIP).

> Apka jest **dumb client** — całe przetwarzanie odbywa się na Twoim własnym
> backendzie. Apka tylko UI + uplink HTTP/JSON.

## Architektura BYO (Bring Your Own backend)

```
┌──────────────┐   HTTPS    ┌─────────────────────┐    ┌──────────────┐
│   iPhone     │  Bearer    │  Twój backend       │    │  MariaDB     │
│  (ta apka)   │ ──────────▶│  FastAPI (port 8000)│───▶│  zbiory      │
└──────────────┘            │  + LanceDB CLIP     │    └──────────────┘
                            │  + Claude API       │
                            └─────────────────────┘
                                     │
                                     ▼
                            ┌────────────────┐
                            │ Anthropic API  │
                            │  (klucz Twój)  │
                            └────────────────┘
```

Apka **nie zbiera żadnych danych centralnie**. Zdjęcia, AI requesty, zapisy
trafiają tylko na backend, którego URL podałeś w Ustawieniach.

## Wymagania

- iPhone iOS 17+ albo iOS Simulator (Xcode 16+)
- Self-hosted backend Inwentaryzacja-Mobile (kod w `../backend/`)
- Klucz Anthropic API (do identify) — Twój własny

## Pierwsze uruchomienie

1. **Postaw backend** — patrz `../backend/README.md` lub
   [docs/BACKEND_SETUP.md](../docs/BACKEND_SETUP.md). Domyślnie nasłuchuje
   na `http://127.0.0.1:8000` (LAN).
2. **Zainstaluj apkę** — TestFlight/AppStore (planowane) albo build lokalny:
   ```bash
   flutter pub get
   flutter run -d <iphone_id>
   ```
3. **Skonfiguruj** — pierwszy ekran apki poprosi o:
   - URL backendu (np. `http://192.168.1.5:8000` w LAN albo `https://api.twoja.domena`)
   - Token API (z `backend/.env` pole `API_TOKEN`)
4. **Zacznij** — gdy panel zdrowia świeci na zielono, używaj „Zrób zdjęcie
   eksponatu" lub „Znajdź podobne".

## Funkcje (stan 2026-04-29, etapy F1–F10)

- ✅ Ustawienia (URL + token, persist na iOS Keychain-bound storage)
- ✅ Healthcheck z weryfikacją tokenu (panel zielony/pomarańczowy/czerwony)
- ✅ Foto z biblioteki lub aparatu, auto-resize do 2048px JPEG q85
- ✅ Identify przez Claude Opus 4.7 (z opcjonalnym DEV mock dla iteracji UI)
- ✅ Formularz edycji eksponatu z autocomplete ze słowników (Cupertino picker)
- ✅ Zapis do MariaDB (multipart upload, BLOB zdjęcia w bazie)
- ✅ Similar search (CLIP embedding + LanceDB) — top 5 wyników z miniaturkami
- ✅ ExhibitDetailPage — szczegóły dowolnego eksponatu z bazy

## Stack

| Warstwa | Technologia |
|---|---|
| UI | Flutter 3.41 / Dart 3.11, **Cupertino-only** (iOS look) |
| State | flutter_riverpod 3.x (AsyncNotifier, FutureProvider.autoDispose) |
| HTTP | pakiet `http` ^1.x |
| Storage | shared_preferences (URL + token) |
| Image | image_picker + pakiet `image` (resize, EXIF rotation) |

## Build

```bash
# iOS Simulator (debug)
flutter build ios --simulator --debug --no-codesign

# Fizyczny iPhone (debug, free dev provisioning 7-day)
flutter run -d <iphone_id>

# Release (wymaga Apple Developer $99/rok i certyfikatu)
flutter build ipa --release
```

Bundle ID: `com.bronkibrothers.inwentaryzacja.mobile` (App Store).

## Prywatność

Patrz [PRIVACY.md](PRIVACY.md). TL;DR: apka nie zbiera niczego centralnie,
wszystkie dane idą tylko na Twój backend.

## Licencja

[MIT](../LICENSE) — komplementarna do desktop `arekbr/Inwentaryzacja`.
