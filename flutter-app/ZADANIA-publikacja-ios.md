# ZADANIA — publikacja aplikacji na iPhone'a

Repo jest publiczne: w tym pliku bez tokenów, danych osobowych i adresu backendu produkcyjnego.

## CO

Aplikacja `flutter-app/` trafia na iPhone'a: najpierw TestFlight wewnętrzny z prawdziwym backendem, potem App Store.

## GOTOWE GDY

1. **Tożsamość:** aplikacja w symulatorze ma nazwę „Inwentaryzacja” i własną ikonę, nie logo Fluttera.
2. **Przebieg:** w symulatorze działa ścieżka przez HTTPS: zdjęcie z biblioteki → rozpoznanie → edycja → zapis → szczegóły → „Znajdź podobne”.
   Aparat i TestFlight sprawdzimy na fizycznym iPhonie. Bez tego nie wysyłamy do recenzji, bo wytyczna 2.1(a) wymaga testu na urządzeniu.
3. **Zgoda na AI:** bez udzielonej zgody żadne zdjęcie nie wychodzi do rozpoznania; ekran zgody nazywa Anthropic; po odmowie reszta aplikacji działa.
4. **Polityka prywatności:** link jest w aplikacji i w App Store Connect, a treść opisuje wersję iOS.
5. **Recenzent:** dostaje osobny adres i token backendu demo. Token demo na produkcji daje 401, token produkcyjny na demo daje 401.
6. **App Store:** status „Ready for Distribution” albo zapisana decyzja o zatrzymaniu się na TestFlight.

## SPRAWDZĘ TAK

| Punkt | Sprawdzenie |
|---|---|
| 1 | Ekran główny iPhone'a i pole „App Name” w TestFlight |
| 2 | Przejście ścieżki na urządzeniu i odczyt zapisanego rekordu drugą drogą (bezpośrednio z bazy) |
| 3 | Test czerwony na obecnym kodzie: wywołanie rozpoznania bez zgody nie może wysłać żądania |
| 4 | Dotknięcie linku na iPhonie, kod HTTP 200 i przeczytanie treści |
| 5 | `curl` obu tokenów na obu adresach, cztery wyniki w raporcie |
| 6 | Status w App Store Connect |

## BRZEGI

- Brak sieci w trakcie rozpoznania i zapisu.
- Błędny token, backend wyłączony.
- Odmowa dostępu do aparatu i biblioteki zdjęć.
- Backend po HTTP w sieci lokalnej: App Transport Security i uprawnienie sieci lokalnej sprawdzimy, gdy będzie urządzenie testowe; symulator tego nie pokaże.
- Jasny i ciemny motyw systemu.

## POZA

- Android (Qt zostaje wersją produkcyjną w Play).
- Developer ID i notaryzacja desktopu.
- Płatne funkcje i Paid Applications Agreement.
- Automatyczne dopisywanie nowych eksponatów do indeksu CLIP.
- Propozycja do decyzji: token w Pęku kluczy zamiast `shared_preferences`.

## ZAŁOŻENIA

- Konto Individual, Team ID `54F7NQRL4S`, aktywne do 6.11.2027.
- Bundle ID `com.bronkibrothers.inwentaryzacja.mobile`, aplikacja darmowa.
- Xcode 26.6 i iOS SDK 26.5 spełniają wymaganie Apple „Xcode 26 lub nowszy”.
- Model „własny backend użytkownika” może nie przejść wytycznej 4.2. Wracamy do tego po TestFlight, zanim zbudujemy kartę produktu.

## Stan startowy (pomiar 5.11.2026)

- Kod `flutter-app/` bez zmian od 29.04.2026, `test/` pusty.
- Nazwa wyświetlana „Mobile”, ikona to domyślne logo Fluttera, brak `DEVELOPMENT_TEAM`.
- Na koncie Apple brak tego Bundle ID. Na maku 0 tożsamości podpisu.
- Urządzenie testowe: na razie tylko symulator. Telefon podłączony do maka nie służy do testów i nic na nim nie instalujemy, dopóki właściciel nie wskaże urządzenia.
- W kodzie brak zgody na AI i brak linku do polityki prywatności.
- Backend produkcyjny działa po HTTPS z poprawnym certyfikatem, bez tokenu odpowiada 401.
- Polityka prywatności (wersja Android) jest publicznie dostępna, HTTP 200.

## Warstwy dodawane

| CO dodaję | PO CO dziś | PROSTSZE ODRZUCONE, BO |
|---|---|---|
| Backend demo dla recenzenta | Wytyczna 2.1(a) wymaga działającego backendu i danych demo | Token produkcyjny daje recenzentowi zapis do prawdziwych danych i koszt API; tryb demo w aplikacji wymaga wcześniejszej zgody Apple |

## Przyrosty

| # | Zakres | Kto | Sprawdzenie |
|---|---|---|---|
| P1 | Konto w Xcode, `DEVELOPMENT_TEAM` | user + Claude | Podpisane archiwum buduje się bez urządzenia |
| P2 | Nazwa i ikona (źródło `play-assets/icon/icon-512-rgb.png`) | Claude, ikonę akceptuje user | Oglądane na ekranie głównym symulatora |
| P3 | Rekord w App Store Connect, wysłanie archiwum; test na urządzeniu, gdy będzie dostępne | Claude + user | Punkty 1 i 2 |
| P4 | Ekran zgody na AI i link do polityki, treść polityki dla iOS | Claude | Punkty 3 i 4 |
| P5 | Backend demo z osobnym tokenem i danymi bez produkcji | Claude, decyzja usera | Punkt 5 |
| P6 | Zrzuty, kategorie wiekowe, etykiety prywatności, status sprzedawcy UE, wysłanie do recenzji | Claude przygotowuje, user akceptuje i wysyła | Punkt 6 |
