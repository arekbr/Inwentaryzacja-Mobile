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
- [ ] `verify-aab.sh`: podpis kluczem przesyłania (jarsigner „jar verified")
- [ ] Smoke test: instalacja → start → ekran powitalny (emulator Android 16 lub Pixel)
- [ ] Notatki wydania wklejone (pl-PL + en-US)
