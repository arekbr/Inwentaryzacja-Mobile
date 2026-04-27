---
title: Polityka prywatności — Inwentaryzacja Mobile
permalink: /privacy/
---

# Polityka prywatności

**Aplikacja:** Inwentaryzacja Mobile (`com.bronkibrothers.inwentaryzacja.mobile`)
**Ostatnia aktualizacja:** 2026-04-27
**Administrator danych:** Arek Bronowicki, kontakt: `claude@bronowicki.com`

---

## 1. Charakter aplikacji

Inwentaryzacja Mobile jest aplikacją **wewnętrzną** dla niewielkiego prywatnego muzeum retro-computingu. Z aplikacji korzysta administrator i uprawnieni kustosze — nie jest to produkt konsumencki ani SaaS dla osób trzecich.

## 2. Jakie dane aplikacja zbiera

| Dane | Skąd | Po co |
|---|---|---|
| Zdjęcie eksponatu | aparat urządzenia (Twoja akcja: „Zrób zdjęcie") | identyfikacja AI + zapis do bazy zbiorów + wyszukiwanie podobnych |
| Pola opisu (nazwa, producent, model, rok, status, miejsce) | klawiatura — Twoja edycja sugerowanych wartości | metadata eksponatu w bazie zbiorów |
| Token API (Bearer) | konfiguracja w ekranie Ustawienia | autoryzacja do prywatnego backendu |
| Adres URL backendu | konfiguracja w ekranie Ustawienia | komunikacja z serwerem |

Aplikacja **NIE** zbiera:
- danych lokalizacyjnych (GPS, sieci Wi-Fi)
- kontaktów, kalendarza, plików spoza katalogu aplikacji
- identyfikatorów reklamowych (AAID), Firebase ID, Google Analytics ID
- raportów awarii do zewnętrznych usług (brak Crashlytics, Sentry, Bugsnag)

## 3. Uprawnienia urządzenia

| Uprawnienie | Po co |
|---|---|
| `CAMERA` | uruchomienie systemowej aplikacji aparatu (Google Camera) do zrobienia zdjęcia eksponatu |
| `INTERNET` | komunikacja z prywatnym backendem (HTTP/HTTPS) |

**Aparat** uruchamiany jest jako *Intent* — czyli systemowa aplikacja Google Camera, która sama kontroluje przechwytywanie obrazu. Nasza aplikacja otrzymuje tylko gotowy plik JPG.

## 4. Gdzie trafiają Twoje dane

```
Twój telefon
    ↓ (HTTPS / WireGuard, sieć prywatna)
Prywatny backend FastAPI
    ↓
MariaDB „zbiory"   ←  baza eksponatów (lokalnie u administratora)
    ↓
Anthropic API (Claude Opus 4.7)   ←  TYLKO przy „Zidentyfikuj"
    └─ Anthropic przetwarza zdjęcie
       żeby zaproponować identyfikację (model, producent, rok).
       Anthropic deklaruje że NIE używa wejść API do treningu modeli
       (https://privacy.anthropic.com/).
```

Backend jest hostowany w sieci prywatnej administratora (dostęp przez tunel WireGuard). Komunikacja telefon ⟷ backend odbywa się w zamkniętej sieci — dane **nie wychodzą do publicznego internetu**, z **jednym wyjątkiem**: gdy użytkownik kliknie „Zidentyfikuj", zdjęcie zostaje przesłane do API Anthropic do analizy AI. Po otrzymaniu wyniku zdjęcie nie jest przechowywane przez Anthropic dłużej niż potrzeba do obsługi żądania (zgodnie z polityką Anthropic dla API enterprise).

## 5. Retencja

- Zdjęcia + metadata: **przechowywane bezterminowo** w bazie muzeum (to jest celem aplikacji — katalog kolekcji).
- Token API w pamięci telefonu: do czasu zmiany przez użytkownika lub odinstalowania aplikacji.
- `allowBackup=false` w manifeście aplikacji blokuje automatyczne backupy Google/ADB — token nie wycieka przez chmurę.

## 6. Z kim dzielimy się danymi

- **Anthropic** (Claude API) — tylko zdjęcie wysłane do identyfikacji AI; brak metadata, brak danych osobowych użytkownika. Anthropic ma własną politykę prywatności i polityka retencji enterprise: https://www.anthropic.com/legal/privacy
- **Nikt inny.** Brak reklam, brak analytics, brak partnerów marketingowych.

## 7. Prawa użytkownika (RODO)

Jako użytkownik aplikacji masz prawo do:
- **dostępu** do swoich danych (zdjęcia + metadata które wysłałeś) — kontakt z administratorem usuwa wątpliwości
- **sprostowania** błędnych metadata — przez ekran „Edytuj eksponat" w aplikacji
- **usunięcia** swoich wpisów z bazy — kontakt z administratorem (`claude@bronowicki.com`)
- **ograniczenia przetwarzania** — możesz przestać używać aplikacji w dowolnej chwili
- **wniesienia skargi** do Prezesa Urzędu Ochrony Danych Osobowych (uodo.gov.pl)

## 8. Bezpieczeństwo

- Komunikacja klient ⟷ backend chroniona tunelem WireGuard (kryptografia ChaCha20-Poly1305, klucze Curve25519)
- Backend wymaga uwierzytelnienia tokenem Bearer (≥16 znaków)
- Wszystkie pola formularza są walidowane po stronie serwera (parametry SQL przez `pymysql %s`, brak SQL injection)
- Limit rozmiaru zdjęć 8 MB, lista dozwolonych formatów: JPEG/PNG/WEBP/HEIF
- Rate limiting: 10 identyfikacji/minutę, 30 wyszukiwań/minutę
- `android:allowBackup="false"` — token API nie wycieka do chmury Google/ADB

## 9. Dane dzieci

Aplikacja **nie jest skierowana do dzieci poniżej 13 lat**. Aplikacja nie zbiera świadomie danych od dzieci. Jeśli administrator dowie się że konto dziecka zostało założone, dane zostaną usunięte.

## 10. Zmiany polityki

W razie istotnych zmian, zaktualizowana wersja zostanie opublikowana w tym samym miejscu (`https://arekbr.github.io/Inwentaryzacja-Mobile/privacy/`) wraz ze zmianą daty „Ostatnia aktualizacja". Użytkownicy aktywni są powiadamiani przez kuratora muzeum przy najbliższej okazji.

## 11. Kontakt

Pytania, sprzeciwy, żądania usunięcia: **`claude@bronowicki.com`**

---

*Aplikacja wydana na licencji MIT. Kod źródłowy: https://github.com/arekbr/Inwentaryzacja-Mobile*
