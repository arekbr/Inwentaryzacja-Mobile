---
title: Release notes — v0.2.0
permalink: /play-store/release-notes-v0.2.0/
---

# Release Notes — v0.2.0 (Android 16 / targetSdk 36)

## Tekst do Play Console — pole „Co nowego" (max 500 znaków per locale)

### Polski (pl-PL)

```
Aktualizacja techniczna pod Androida 16.

• Zgodność z Androidem 16 (targetSdk 36) i urządzeniami z 16 KB stronami pamięci
• Nowsza biblioteka Qt 6.11
• Bez zmian w funkcjach: aparat, rozpoznawanie AI, podobne eksponaty, zapis do bazy

Minimalna wersja Androida: 9 (wcześniej 8).
```

### English (en-US)

```
Technical update for Android 16.

- Android 16 compatibility (targetSdk 36) and 16 KB page-size devices
- Updated Qt 6.11 framework
- No feature changes: camera, AI identification, similar exhibits, save to database

Minimum Android version: 9 (was 8).
```

## Checklista przed „Rozpocznij wdrażanie"

- [x] `verify-aab.sh`: 16 KB alignment wszystkich `.so` = OK; manifest: targetSdk 36 / minSdk 28 / 0.2.0
- [x] `verify-aab.sh`: podpis kluczem przesyłania (jarsigner „jar verified") — 09.09.2026, 72/72 `.so` = 0x4000
- [x] Smoke test: emulator Android 16 (`pixel_api36`), ten sam AAB przez `bundletool build-apks/install-apks` — kod 117 startuje, ekran powitalny renderuje się, 0 FATAL
- [x] Notatki wydania wklejone (tylko `pl-PL` — listing sklepu ma jeden język, tag `<en-US>` nie ma gdzie trafić)

## Stan publikacji

- **09.09.2026 15:2x CEST** — AAB `117 (0.2.0)` wgrany do ścieżki produkcyjnej (nowy klucz przesyłania zaakceptowany; reset klucza wszedł w życie 09.09 o 15:08 CEST).
- **09.09.2026 15:35 CEST** — zmiana wysłana do sprawdzenia przez Google (pełne wdrożenie 100 %). Weryfikacja zwykle do 7 dni.
- Ostrzeżenia Console (świadome, nieblokujące): utrata 947 obsługiwanych urządzeń (minSdk 26 → 28 wymuszone przez Qt 6.11) oraz brak pliku deobfuscation R8/ProGuard.
- Poprzednia wersja `98 (0.1.0)` pozostawiona jako nieuwzględniona w tym wydaniu.
