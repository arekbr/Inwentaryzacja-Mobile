---
title: Store Listing — Polski
permalink: /play-store/listing-pl/
---

# Store Listing (Polski) — gotowe do skopiowania

## App name (max 30 znaków)

```
Inwentaryzacja
```

*(14 zn — bez sufiksu „Mobile" bo to oczywiste z marketu mobilnego; spójne z display name w app drawer)*

## Krótki opis (max 80 znaków)

```
Mobilny katalog kolekcji retro-computingu z rozpoznawaniem AI
```

*(60 zn)*

## Pełny opis (max 4000 znaków)

```markdown
Inwentaryzacja to mobilny klient open-source do katalogowania prywatnych kolekcji retro-computingu — komputery, peryferia, dyskietki, kasety, manuale, akcesoria. Zaprojektowane dla kolekcjonerów którzy chcą prowadzić cyfrowy katalog w terenie, na giełdach lub w piwnicy, z minimalnym tarciem.

CO POTRAFI

• Robi zdjęcie eksponatu używając systemowej aplikacji aparatu (HDR+, Night Sight na Pixel) — żadnego kompromisu jakości jakim grzeszą wbudowane kamery w aplikacjach.

• Wysyła zdjęcie do Twojego prywatnego backendu, gdzie sztuczna inteligencja (Claude od Anthropic) proponuje rozpoznanie modelu, producenta i przybliżonego roku produkcji. Edytujesz, korygujesz i zapisujesz do bazy.

• Wyszukuje wizualnie podobne eksponaty w Twojej kolekcji — wyciągasz nieznany komputer z półki, robisz zdjęcie, w sekundę widzisz pięć najbliższych dopasowań z bazy. CLIP embedding + cosine similarity.

• Pełna baza tekstowa po naciśnięciu „Przeglądaj bazę" — przewijasz miniaturki, otwierasz szczegóły, czytasz opisy muzealne.

DLA KOGO

To nie jest aplikacja konsumencka. Jest dla osób, które:

• mają własną kolekcję eksponatów retro
• chcą prowadzić jej cyfrowy katalog dla porządku, ubezpieczenia, dziedziczenia lub wystawy
• potrafią uruchomić własny serwer (kod backendu jest open-source w tym samym repozytorium GitHub) — albo mają znajomego, który to potrafi
• cenią sobie fakt że ich dane zostają w ich sieci, nie idą do żadnej chmury aplikacji-dostawcy

JAK DZIAŁA

Aplikacja jest „dumb client" — wszystkie dane przepływają wyłącznie między urządzeniem a Twoim własnym backendem (FastAPI + MariaDB, kod w tym samym repo). Po zainstalowaniu w Ustawieniach wpisujesz adres URL swojego backendu i token API. Bez tej konfiguracji aplikacja nic nie robi — żadnych telemetrii, statystyk, reklam ani identyfikatorów reklamowych. Autor aplikacji nie ma serwera ani dostępu do żadnych danych.

WYMAGANIA

• Android 8.0+ (API 26) — Pixel/Samsung/OnePlus/inne flagshipy
• Własny backend (FastAPI, kod open-source) — uruchomiony lokalnie albo na własnym VPS
• Klucz API Anthropic (Claude) — opcjonalny, tylko jeśli chcesz korzystać z rozpoznawania AI

Pełna dokumentacja, instrukcje uruchomienia backendu, schemat bazy MariaDB i kod źródłowy: github.com/arekbr/Inwentaryzacja-Mobile

LICENCJA

MIT — możesz forkować, modyfikować, publikować pod swoją marką. Aplikacja jest publikowana w Play Store żeby nie trzeba było jej side-loadować przy każdej wymianie telefonu.
```

*(2640 zn)*

## What's new (release notes — pierwsza publikacja v0.1.0)

```
Pierwsza publiczna wersja aplikacji.

• Aparat z HDR+ przez systemowy Intent
• Rozpoznawanie eksponatu przez AI (Claude od Anthropic)
• Wyszukiwanie podobnych przez CLIP embedding (top-5)
• Edycja metadanych i zapis do prywatnej bazy
• Przegląd całej kolekcji w aplikacji
```

## Tags / kategorie

- **Aplikacja:** Productivity (Wydajność)
- **Kategoria drugorzędna:** Tools (Narzędzia)
- **Tag-i:** retro computing, kolekcjonerstwo, katalog, AI
