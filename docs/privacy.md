---
title: Polityka prywatności — Inwentaryzacja Mobile
permalink: /privacy/
---

# Polityka prywatności

**Aplikacja:** Inwentaryzacja Mobile (`com.bronkibrothers.inwentaryzacja.mobile`)
**Ostatnia aktualizacja:** 2026-04-27
**Autor aplikacji (kod źródłowy):** Arek Bronowicki — kontakt: `dev@bronkibrothers.com`

---

## TL;DR — co aplikacja robi z danymi

**Nic.** Sam autor aplikacji **nie zbiera żadnych danych** od użytkowników:

- Aplikacja nie ma wbudowanego serwera ani usługi w chmurze.
- Aplikacja nie wysyła telemetrii, analytics, raportów awarii ani identyfikatorów reklamowych — nigdzie.
- Aplikacja **nie działa** dopóki użytkownik sam nie poda w `Ustawieniach` adresu URL **swojego własnego backendu** + tokenu API.

Dopiero **operator własnego backendu** (np. muzeum, prywatny kolekcjoner) decyduje co dzieje się z danymi po ich wysłaniu. Autor aplikacji **nie ma dostępu** do żadnego backendu użytkownika ani do żadnych danych, które tam trafią.

## 1. Charakter aplikacji

Inwentaryzacja Mobile to **klient open-source** (licencja MIT) do katalogowania kolekcji retro-computingu. Aplikacja jest przeznaczona dla osób które:

- mają własną kolekcję eksponatów retro (komputery, peryferia, oprogramowanie)
- chcą prowadzić jej cyfrowy katalog
- uruchomiły **swój własny backend** (kod backendu również open-source, w tym samym repo)

Apka jest „dumb client" — wszystkie dane przepływają wyłącznie między urządzeniem użytkownika a backendem operatora.

## 2. Co aplikacja zbiera lokalnie na urządzeniu

| Dane | Skąd | Gdzie |
|---|---|---|
| Adres URL backendu | wpisany przez użytkownika w Ustawieniach | `QSettings` w sandboxie aplikacji (`/data/data/<package>/`) |
| Token API (Bearer) | wpisany przez użytkownika w Ustawieniach | `QSettings` j.w., `android:allowBackup="false"` blokuje backup do chmury Google |
| Tymczasowy plik zdjęcia | po naciśnięciu „Zrób zdjęcie" → systemowa Google Camera | `getExternalFilesDir(Pictures)` — kasowane przy odinstalowaniu apki |

**Aplikacja nie wysyła tych danych nigdzie autorowi.** Token API trafia tylko jako nagłówek `Authorization: Bearer …` do URLa backendu który użytkownik sam podał.

## 3. Dane wysyłane na serwer — TYLKO gdy użytkownik konfiguruje backend

Po skonfigurowaniu URL i tokenu w Ustawieniach, użytkownik może świadomie:

- **kliknąć „Zidentyfikuj"** → zdjęcie eksponatu wysłane do **jego** backendu
- **kliknąć „Szukaj podobnych"** → zdjęcie wysłane do **jego** backendu
- **kliknąć „Zapisz do bazy"** → zdjęcie + metadata wysłane do **jego** backendu

Każda z tych operacji wymaga **świadomego, jawnego kliknięcia** użytkownika. Apka nie przesyła danych w tle.

**Co backend zrobi z tymi danymi to wyłączna decyzja operatora backendu** — nie autora aplikacji. Jeśli stawiasz backend dla cudzych użytkowników, to Ty (operator) odpowiadasz za politykę prywatności swojego backendu — niniejszy dokument tej kwestii nie dotyczy.

## 4. Anthropic API — opcjonalne, kontrolowane przez operatora backendu

Domyślny kod backendu (open-source, w tym samym repo) **może** używać API Claude (Anthropic) do funkcji „Zidentyfikuj" — Claude analizuje zdjęcie eksponatu i proponuje model/producenta/rok. **Ale:**

- to **opcjonalna funkcja** — operator backendu sam decyduje czy ją włącza (`ANTHROPIC_API_KEY` w `.env` backendu, opcjonalny tryb `DEV_MOCK_IDENTIFY=true`)
- jeśli operator backendu **nie ustawi klucza Anthropic** → funkcja nie działa, **żadne dane nie wychodzą** poza jego sieć
- jeśli operator włącza Anthropic API → operator (nie autor aplikacji) jest odpowiedzialny za zgodę użytkownika końcowego

Polityka Anthropic dla API: https://www.anthropic.com/legal/privacy (Anthropic deklaruje że nie używa wejść API do treningu modeli).

## 5. Uprawnienia urządzenia

| Uprawnienie | Po co |
|---|---|
| `CAMERA` | uruchomienie systemowej aplikacji aparatu (Google Camera) — apka NIE czyta z aparatu sama, tylko deleguje do Google Camera przez Intent |
| `INTERNET` | wysłanie HTTP request do URLa backendu **wpisanego przez użytkownika** — domyślnie aplikacja niczego nie wysyła |

## 6. Co aplikacja NIE zbiera (definitywnie)

- danych lokalizacyjnych (GPS, sieci Wi-Fi, BLE)
- kontaktów, kalendarza, plików spoza katalogu apki
- identyfikatorów reklamowych (AAID), Firebase ID, Google Analytics ID, AppMetrica
- raportów awarii do zewnętrznych usług (Crashlytics, Sentry, Bugsnag)
- żadnej telemetrii, statystyk użycia, heatmap, A/B-testów
- numerów IMEI/IMSI, MAC, numerów seryjnych telefonu

## 7. Z kim autor dzieli się danymi

**Z nikim.** Autor aplikacji nie ma żadnego serwera, do którego apka by się łączyła. Wszelkie połączenia sieciowe idą na URL **wpisany przez użytkownika w Ustawieniach** (jego własny backend).

## 8. Prawa użytkownika (RODO)

W zakresie **danych zapisanych w aplikacji na urządzeniu** (URL backendu, token):
- masz pełną kontrolę — możesz je zmienić w `Ustawieniach` lub usunąć przez odinstalowanie aplikacji.

W zakresie **danych wysłanych do Twojego backendu**:
- skontaktuj się z operatorem backendu (osobą która prowadzi serwer pod URL który wpisałeś w Ustawieniach) — to nie jest autor aplikacji.

W zakresie **kodu źródłowego aplikacji** (autora):
- pytania, zgłoszenia bugów, pull requests: **`dev@bronkibrothers.com`** lub https://github.com/arekbr/Inwentaryzacja-Mobile/issues

## 9. Bezpieczeństwo

- `android:allowBackup="false"` — token API nie wycieka do chmury Google przy automatycznym backupie urządzenia.
- Walidacja zdjęć przed wysłaniem (rozmiar ≤ 8 MB, typ JPEG/PNG/WEBP/HEIF).
- Resize zdjęć do max 2048 px przed uploadem (oszczędność transferu + redukcja metadanych EXIF GPS, jeśli aparat je dodał).
- Brak hard-codowanych URL ani tokenów w aplikacji — wszystko ustawiane w runtime przez użytkownika.

## 10. Dane dzieci

Aplikacja nie jest skierowana do dzieci poniżej 13 lat. Aplikacja nie zbiera danych od żadnego użytkownika — patrz sekcja 2.

## 11. Zmiany polityki

W razie zmian, zaktualizowana wersja zostanie opublikowana w `https://arekbr.github.io/Inwentaryzacja-Mobile/privacy/` z nową datą „Ostatnia aktualizacja". Repo na GitHub przechowuje pełną historię zmian polityki.

## 12. Kontakt

Pytania o aplikację (kod, działanie, bugi): **`dev@bronkibrothers.com`**

---

*Aplikacja wydana na licencji MIT. Kod źródłowy aplikacji i backendu: https://github.com/arekbr/Inwentaryzacja-Mobile*
