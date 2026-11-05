---
title: Polityka prywatności — Inwentaryzacja Mobile
permalink: /privacy/
---

# Polityka prywatności

**Aplikacja:** Inwentaryzacja Mobile (`com.bronkibrothers.inwentaryzacja.mobile`), Android i iOS
**Ostatnia aktualizacja:** 2026-11-05
**Autor aplikacji:** Arek Bronowicki, kontakt: `dev@bronkibrothers.com`

---

## W skrócie

- Aplikacja łączy się z serwerem (backendem) podanym w Ustawieniach. Wybrane zdjęcia i dane eksponatów trafiają do operatora tego serwera.
- Przy rozpoznawaniu przez AI serwer przekazuje zdjęcie firmie Anthropic. Na iOS wymaga to zgody w aplikacji.
- Aplikacja nie zawiera reklam, analityki ani zewnętrznych raportów awarii.

## 1. Kto otrzymuje dane

Odbiorcą danych jest **operator serwera podanego w Ustawieniach**, na przykład muzeum albo kolekcjoner prowadzący własny serwer. To on decyduje, jak długo przechowuje dane, i to do niego należy kierować prośby o ich usunięcie.

Autor aplikacji otrzymuje dane tylko wtedy, gdy łączysz się z serwerem, który sam prowadzi. Autor prowadzi serwer własnej kolekcji oraz serwer demonstracyjny do sprawdzenia aplikacji przez recenzenta sklepu. Serwer demonstracyjny zawiera dane przykładowe, a zapisane na nim dane mogą zostać usunięte bez uprzedzenia.

## 2. Co aplikacja przechowuje na urządzeniu

| Dane | Gdzie |
|---|---|
| Android: adres serwera i token API | ustawienia aplikacji (`QSettings`), `android:allowBackup="false"` wyklucza je z kopii zapasowej Google |
| Android: tymczasowy plik zdjęcia | katalog zdjęć aplikacji, kasowany przy odinstalowaniu |
| iOS: adres serwera | `UserDefaults` w sandboxie aplikacji |
| iOS: token API | Pęk kluczy iOS, tylko na tym urządzeniu |
| iOS: zgoda na rozpoznanie przez AI | `UserDefaults` w sandboxie aplikacji |
| iOS: zdjęcie wybrane do wysłania | katalog tymczasowy aplikacji |

## 3. Co aplikacja wysyła

Do serwera podanego w Ustawieniach trafiają:

- **zdjęcie**, gdy naciśniesz „Zidentyfikuj” albo uruchomisz wyszukiwanie podobnych eksponatów,
- **zdjęcie i dane z formularza**, gdy zapiszesz eksponat,
- **token API** w nagłówku każdego żądania wymagającego uwierzytelnienia.

Serwer widzi też adres IP połączenia i używa go do ograniczania liczby żądań oraz ochrony przed nadużyciami.

Zdjęcia i formularze są wysyłane po Twoim działaniu. Aplikacja automatycznie sprawdza też dostępność serwera i poprawność tokenu, na Androidzie co 15 sekund, gdy widoczny jest ekran główny.

Aplikacja skaluje zdjęcia do najwyżej 2048 px i zapisuje je jako JPEG. Wersja iOS usuwa z nich metadane EXIF, w tym lokalizację GPS. Serwer sprawdza format i limit 8 MiB na zdjęcie, z wyjątkiem trybu demonstracyjnego rozpoznawania.

Wersja Android ma wstępnie ustawiony przykładowy adres w sieci lokalnej, który należy zastąpić adresem swojego serwera. Link do polityki prywatności otwiera tę stronę w GitHub Pages.

## 4. Rozpoznawanie przez AI (Anthropic)

Funkcja „Zidentyfikuj” działa na serwerze. Przy rzeczywistym rozpoznawaniu serwer wysyła zdjęcie do API Anthropic, które obsługuje model AI Claude. Wymaga to klucza Anthropic ustawionego przez operatora. W trybie demonstracyjnym serwer zwraca stały, przykładowy wynik i nie łączy się z Anthropic.

**Zgoda na iOS.** Przed wysłaniem zdjęcia do rozpoznania aplikacja wymaga zapisanej zgody. Jeśli nie udzielono jej wcześniej w Ustawieniach, wyświetla pytanie, które wskazuje serwer i firmę Anthropic. Bez zgody zdjęcie nie jest wysyłane do rozpoznania, a nadal można przeglądać bazę i szukać podobnych eksponatów. Dodanie nowego eksponatu wymaga obecnie przejścia przez rozpoznanie.

**Android.** Rozpoznanie uruchamiasz przyciskiem. Wersja Android nie wyświetla osobnego pytania o zgodę.

**Ochrona danych u odbiorców.** W kodzie serwera jedynym zewnętrznym odbiorcą danych jest Anthropic, działający na warunkach dla klientów API. Autor uznaje te warunki za zapewniające ochronę co najmniej równą opisanej w tej polityce. Operator innego serwera odpowiada za to, by każdy odbiorca, któremu sam przekazuje dane, zapewniał taką samą ochronę. Anthropic deklaruje, że domyślnie [nie używa wejść ani wyjść produktów komercyjnych do treningu modeli](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training), a [dane API co do zasady usuwa w ciągu 30 dni](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data). Obie deklaracje mają wyjątki opisane na tych stronach.

## 5. Uprawnienia

| Uprawnienie | Po co |
|---|---|
| Android: `CAMERA` | uruchomienie aplikacji aparatu przez systemowy `ACTION_IMAGE_CAPTURE` |
| Android: `INTERNET` | połączenie z serwerem |
| iOS: aparat | zrobienie zdjęcia eksponatu |
| iOS: biblioteka zdjęć | wybranie zdjęcia eksponatu; aplikacja odczytuje tylko zdjęcie wskazane przez Ciebie |

## 6. Czego aplikacja nie robi

- nie odczytuje lokalizacji przez interfejsy urządzenia,
- nie odczytuje kontaktów ani kalendarza,
- nie korzysta z identyfikatorów reklamowych (AAID, IDFA),
- nie zawiera analityki, reklam ani zewnętrznych raportów awarii.

## 7. Przechowywanie, usuwanie i wycofanie zgody

- **Ustawienia na urządzeniu** zostają do ich zmiany albo odinstalowania aplikacji.
- **Token na iOS:** wyczyść pole „Token API” i naciśnij „Zapisz”. Samo odinstalowanie aplikacji może zostawić go w Pęku kluczy.
- **Zdjęcia tymczasowe** leżą w katalogu aplikacji do czasu ich usunięcia przez system albo odinstalowania aplikacji.
- **Dane na serwerze:** czas przechowywania ustala operator i do niego kierujesz prośbę o usunięcie.
- **Wycofanie zgody na iOS:** wyłącz przełącznik zgody w Ustawieniach. Nie cofa to wysłania zdjęć przekazanych wcześniej; ich dotyczy prośba do operatora.

Jeśli masz pytania o dane w aplikacji albo na serwerze prowadzonym przez autora, napisz na `dev@bronkibrothers.com`.

## 8. Dane dzieci

Aplikacja nie jest skierowana do dzieci poniżej 13 lat.

## 9. Zmiany polityki

Zaktualizowana wersja pojawia się pod adresem `https://arekbr.github.io/Inwentaryzacja-Mobile/privacy/` z nową datą. Repozytorium na GitHubie przechowuje historię zmian.

---

*Aplikacja na licencji MIT. Kod źródłowy aplikacji i serwera: https://github.com/arekbr/Inwentaryzacja-Mobile*
