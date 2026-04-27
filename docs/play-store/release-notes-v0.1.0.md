---
title: Release notes — v0.1.0
permalink: /play-store/release-notes-v0.1.0/
---

# Release Notes — v0.1.0 (pierwsza publikacja)

## Tekst do Play Console — pole „What's new" (max 500 znaków per locale)

### Polski (pl-PL)

```
Pierwsza publiczna wersja aplikacji.

• Aparat z HDR+ przez systemowy Intent
• Rozpoznawanie eksponatu przez AI (Claude od Anthropic)
• Wyszukiwanie podobnych przez CLIP embedding (top-5 z bazy)
• Edycja metadanych i zapis do prywatnej bazy
• Przegląd całej kolekcji w aplikacji

Wymaga uruchomienia własnego backendu (open-source, instrukcje w README na GitHub).
```

*(391 zn)*

### English (en-US) — opcjonalne fallback dla rynków poza PL

```
First public release.

- Photo capture via system Camera Intent (HDR+, Night Sight on Pixel)
- AI exhibit identification (Claude by Anthropic)
- Visual similarity search via CLIP embedding (top-5 from collection)
- Metadata edit and save to private database
- Full collection browser

Requires self-hosted backend (open-source, see GitHub README).
```

*(379 zn)*

---

## Internal pre-release checklist

Przed kliknięciem „Start rollout" w Internal Testing:

- [ ] AAB podpisany przez upload key (`jarsigner -verify` zwraca „jar verified")
- [ ] Privacy Policy URL działa (HTTP 200)
- [ ] App icon 512×512 wgrany do Play Console
- [ ] Min 2 screenshoty wgrane (zalecane 4-6)
- [ ] App content (Privacy / Data Safety / Content Rating / Target Audience / Permissions) wypełnione
- [ ] Lista testerów dodana (e-maile Google account, max 100)
- [ ] Tester opt-in URL skopiowany — wyślij testerom

Po roll-out internal:

- [ ] Każdy tester potwierdza że dostał update z Play Store (5-30 min propagacja)
- [ ] Smoke test: install → konfiguruj URL+token → zrób zdjęcie → identify → save
- [ ] Sprawdź Pre-launch report w Play Console (automatyczne testy Google na różnych urządzeniach)

## Po teście internal

Jeśli testy bez bugów przez tydzień, można:
1. Promować do **Closed testing** (rozszerza listę do 100-1000 testerów po e-mailach)
2. Albo do **Open testing** (każdy może się zapisać przez Play Store opt-in URL)
3. Albo **Production** (dla wszystkich z aktywnym Play Store)

Versioning po teście:
- v0.1.0 → v0.2.0 (pierwsza stable)
- versionCode 1 → 2 w `android-app/CMakeLists.txt`
