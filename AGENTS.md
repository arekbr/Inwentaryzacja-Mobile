# AGENTS.md — Inwentaryzacja-Mobile

Stan: 5.11.2026. Repo jest publiczne: bez tokenów, danych osobowych i adresu backendu produkcyjnego.

## Co tu jest

- `android-app/` — Qt 6, wersja produkcyjna w Google Play.
- `flutter-app/` — klient iOS (Flutter, Cupertino, Riverpod), w trakcie publikacji w App Store. Karta: `flutter-app/ZADANIA-publikacja-ios.md`.
- `backend/` — FastAPI wspólny dla obu klientów.
- `docs/` — strona GitHub Pages z gałęzi `main`, w tym polityka prywatności.

Praca: gałąź funkcji → `dev` → `main`.

## Drogi odrzucone

- **Qt na iOS:** statyczne linkowanie wymusza licencję komercyjną albo otwarcie kodu, a interfejs nie wygląda natywnie.
- **SwiftUI obok Androida:** dwa kody dla jednej osoby rozjeżdżają się.
- **Token produkcyjny dla recenzenta Apple:** daje zapis do prawdziwej bazy i koszt API. Recenzent dostaje osobny backend demo.
- **Tryb demo w aplikacji:** wytyczna 2.1(a) wymaga na to wcześniejszej zgody Apple.

## Miny

- **Budowanie na urządzenie po `--no-codesign`:** zostaje niepodpisany `objective_c.framework`, a instalacja pada z komunikatem `Error running application`. Przed budowaniem na urządzenie albo do sklepu: `flutter clean`. Kontrola: `codesign -dv` na tym składniku ma pokazać identyfikator zespołu.
- **Pęk kluczy iOS przeżywa odinstalowanie aplikacji:** token usuwa się, czyszcząc pole w Ustawieniach.
- **Duży tekst systemowy:** ekrany muszą się przewijać. Test: `flutter-app/test/large_text_test.dart`.
- **Testy Fluttera na macOS:** bez atrap `SharedPreferences` i `FlutterSecureStorage` ekran czeka na platformę i test mierzy nie to, co trzeba.
- **Nowy eksponat nie trafia sam do indeksu CLIP:** „Znajdź podobne” widzi go dopiero po `backend/scripts/build_embeddings.py`.
- **Pole `value` eksponatu jest prywatne:** nie wolno go wystawiać w danych demo ani w materiałach publicznych.

## Metoda

Nowa funkcja zaczyna się od karty `ZADANIA-<temat>.md`. Błąd w działaniu: najpierw test czerwony na starym kodzie, potem poprawka, potem mutant, który ten test znowu czerwieni.
