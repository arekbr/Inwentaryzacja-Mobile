---
title: Release notes — v0.2.1
permalink: /play-store/release-notes-v0.2.1/
---

# Release Notes — v0.2.1 (edge-to-edge)

## Tekst do Play Console — pole „Co nowego" (max 500 znaków per locale)

### Polski (pl-PL)

```
Poprawki wyglądu na nowszych Androidach.

• Po zrobieniu zdjęcia wraca pasek stanu z zegarem — wcześniej zostawał czarny pas
• Przyciski na dole ekranu nie chowają się już pod paskiem gestów
• Bez zmian w funkcjach: aparat, rozpoznawanie AI, podobne eksponaty, zapis do bazy
```

### English (en-US)

```
Display fixes for newer Android versions.

• The status bar with the clock comes back after taking a photo — it used to stay black
• Buttons at the bottom of the screen no longer hide under the gesture bar
• No functional changes: camera, AI recognition, similar exhibits, saving to the database
```

> 🔴 Listing sklepu ma **jeden język (pl-PL)** — Console podsuwa wyłącznie ten tag. Tekst en-US
> zostaje tu na wypadek dodania drugiego języka listingu (tak samo było przy 0.2.0).

## Co dokładnie poszło do wydania

| Zmiana | Plik | Dowód |
|---|---|---|
| Przywrócenie pasków systemowych po Intencie aparatu | `MainActivity.java` (`onResume` → `WindowInsetsControllerCompat.show`) | `dumpsys window`: `visible=false` → `visible=true`, zegar wraca na zrzucie |
| Dolny inset na pięciu stronach | `CameraPage`, `ExhibitListPage`, `SimilarPage`, `ExhibitDetailPage`, `SettingsPage` | przyciski nad paskiem gestów, `SafeArea.margins.bottom = 24` |
| Zerwanie samo-referencji safe area w ToolBarze | `Main.qml` | brak ostrzeżeń o pętli wiązań w logcat |

## Czego świadomie NIE zrobiono

- **R8** (zalecenie Play „Twoja aplikacja nie jest zoptymalizowana"): Qt daje gołe `.jar` bez
  consumer keep rules, a aparat woła Javę przez JNI po nazwie. Bez własnych reguł keep R8
  wyciąłby główną funkcję apki — cicho, dopiero w buildzie release.
- **Wycinanie nieużywanych stylów QtQuick Controls**: 2,82 MB po kompresji z 20,65 MB pobierania.
  Jedyny wspierany mechanizm wyłącza automatyczne wykrywanie zależności i wymaga ręcznej listy
  wszystkich bibliotek, wtyczek i modułów QML. Styl Basic i tak musi zostać (Fusion importuje go
  wprost, `StackView` istnieje tylko w Basic).
- **Zdjęcie podłogi 60 px** w górnym pasku: zmierzone 52 px, ale na emulatorze **bez wyspy
  aparatu**. Podłoga może być tylko za duża (kosmetyka), jej brak może być za mały (treść pod
  wyspą) na urządzeniu, którego nie zmierzono.

## Ścieżka publikacji

1. Testy wewnętrzne (nie produkcja) — to jedyny sposób dotknięcia artefaktu **przepodpisanego
   kluczem Google**, czyli tego, co realnie dostaje użytkownik.
2. Smoke test z tej ścieżki na fizycznym Pixelu.
3. Dopiero potem promocja na produkcję.

## Stan publikacji

- [x] `versionName` 0.2.1, `CHANGELOG.md`
- [ ] PR `fix/edge-to-edge-and-slim-styles` → `dev` → `main`
- [ ] `git tag v0.2.1`
- [ ] Podpisany AAB z `main` + `verify-aab.sh`
- [ ] Uruchomienie **podpisanego AAB** (bundletool `build-apks --local-testing` + `install-apks`)
- [ ] Upload na ścieżkę testów wewnętrznych + wysłanie do sprawdzenia
- [ ] Smoke test na Pixelu z wersji ze sklepu
- [ ] Promocja na produkcję
