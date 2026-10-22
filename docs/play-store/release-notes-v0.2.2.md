---
title: Release notes — v0.2.2
permalink: /play-store/release-notes-v0.2.2/
---

# Release Notes — v0.2.2 (HTTPS)

## Tekst do Play Console — pole „Co nowego" (max 500 znaków per locale)

### Polski (pl-PL)

```
Bezpieczne połączenie z serwerem.

• Aplikacja łączy się z serwerem szyfrowanym połączeniem (https://) — działa z dowolnego miejsca z internetem, bez VPN
• Po zrobieniu zdjęcia wraca pasek stanu z zegarem
• Przyciski na dole ekranu nie chowają się już pod paskiem gestów
• Bez zmian w funkcjach: aparat, rozpoznawanie AI, podobne eksponaty, zapis do bazy
```

### English (en-US)

```
Secure connection to the server.

• The app connects to the server over an encrypted connection (https://) — works anywhere with internet, no VPN
• The status bar with the clock comes back after taking a photo
• Buttons at the bottom of the screen no longer hide under the gesture bar
• No functional changes: camera, AI recognition, similar exhibits, saving to the database
```

> 🔴 Listing sklepu ma **jeden język (pl-PL)** — Console podsuwa wyłącznie ten tag. Tekst en-US
> zostaje tu na wypadek dodania drugiego języka listingu.
> W produkcji była 0.2.0 (kod 117); 0.2.1 (kod 124) stała tylko na ścieżce testów wewnętrznych,
> dlatego notatki 0.2.2 zawierają także jej poprawki.

## Co dokładnie poszło do wydania

| Zmiana | Plik | Dowód |
|---|---|---|
| Biblioteki OpenSSL w pakiecie (KDAB/android_openssl, przypięty commit + suma archiwum) | `android-app/CMakeLists.txt` | 0.2.0 na Pixelu: „✗ Sieć: TLS initialization failed (kod 99)” przy `https://`; po zmianie w APK są `libssl_3.so` i `libcrypto_3.so` (16 KB align) |
| `verify-aab.sh` wymaga `libssl_3.so` i `libcrypto_3.so` | `scripts/verify-aab.sh` | stary AAB 0.2.0 → RC=1 z listą brakujących bibliotek |
| Wersja 0.2.2 | `android-app/CMakeLists.txt` | `versionName` w manifeście AAB |
