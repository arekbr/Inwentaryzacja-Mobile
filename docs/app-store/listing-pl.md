---
title: Opis aplikacji w App Store
---

# Opis w App Store

**Nazwa:** Inwentaryzacja

**Podtytuł:** Katalog kolekcji retro

**Kategoria:** Produktywność, dodatkowo Narzędzia

**Słowa kluczowe:** kolekcja,retro,muzeum,katalog,eksponaty,zbiory,kolekcjoner,AI,komputery,inwentaryzacja

**Adres pomocy:** https://github.com/arekbr/Inwentaryzacja-Mobile/issues

**Polityka prywatności:** https://arekbr.github.io/Inwentaryzacja-Mobile/privacy/

**Tekst promocyjny:** Sfotografuj eksponat, a AI zaproponuje jego opis. Katalog retro-kolekcji na Twoim własnym serwerze.

## Opis

Aplikacja prowadzi katalog kolekcji retro: komputerów, peryferiów i powiązanych eksponatów. Katalog jest przechowywany na Twoim własnym serwerze.

Co możesz zrobić:

- zrobić zdjęcie eksponatu aparatem albo wybrać je z biblioteki,
- poprosić AI o rozpoznanie eksponatu i propozycję opisu,
- poprawić dane i zapisać eksponat w swojej bazie,
- przeglądać bazę eksponatów ze zdjęciami,
- znaleźć eksponaty podobne do zdjęcia.

Aplikacja wymaga własnego serwera. Jego kod jest otwarty, a instrukcja instalacji znajduje się w repozytorium projektu. Bez skonfigurowanego serwera aplikacja nie przegląda ani nie zapisuje danych.

Prywatność: rozpoznanie wymaga Twojej zgody. Zdjęcie trafia wtedy na Twój serwer, a stamtąd do firmy Anthropic, która obsługuje model AI Claude. Zgodę możesz wycofać w Ustawieniach. Aplikacja usuwa ze zdjęć metadane EXIF, w tym lokalizację, a token dostępu do serwera przechowuje w Pęku kluczy iOS. Nie zawiera reklam ani analityki.

## Informacje dla recenzenta (po angielsku)

This app is a client for a self-hosted museum inventory server, so it needs a server address and an API token.

To test it:

1. Open **Ustawienia** (Settings) on the home screen.
2. In **URL backendu** enter the demo server address supplied in these notes.
3. In **Token API** enter the value from the Password field of the sign-in information.
4. Tap **Zapisz** (Save), dismiss the confirmation with **OK** and return to the home screen. A green dot and the label **OK** confirm the connection and the token.

Then you can use **Zrób zdjęcie eksponatu** (take a photo), **Przeglądaj bazę** (browse the database) and **Znajdź podobne** (find similar).

This demo server holds sample data. On it, identification returns a fixed sample result and does not call any external AI service, so the result will not match your photo. Before a photo is sent for identification the app requires stored consent and, if it has not been given in Settings, asks for it, because on a regular server the photo is passed on to Anthropic. **Choose Zgadzam się (I agree) to continue.**

The interface is in Polish.
