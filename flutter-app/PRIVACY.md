# Polityka prywatności — Inwentaryzacja Mobile

**Ostatnia aktualizacja: 2026-04-29**

## TL;DR

Aplikacja Inwentaryzacja Mobile **nie zbiera żadnych danych** o Tobie ani Twoich
eksponatach. Apka jest klientem self-hosted backendu, który **stawiasz Ty sam
na własnym serwerze**. Wszystkie dane (zdjęcia, opisy, tokeny, identyfikacje
AI) trafiają wyłącznie do tego backendu.

Twórcy apki nie mają dostępu do żadnych Twoich danych.

## Jakie dane apka przechowuje lokalnie

Na Twoim iPhonie, w obrębie sandboxa apki:

- **URL Twojego backendu** (np. `https://api.twoja.domena`)
- **Token API** do uwierzytelnienia z Twoim backendem
- **Cache zdjęć** robionych aparatem przed wysyłką (tymczasowy folder, system
  iOS może go wyczyścić w dowolnym momencie)

Te dane **nie opuszczają Twojego telefonu** poza wysyłką do skonfigurowanego
backendu.

## Jakie dane są wysyłane

Apka wysyła wyłącznie do skonfigurowanego przez Ciebie URL backendu:

- Zdjęcia eksponatów (resize do 2048px JPEG przed wysłaniem)
- Pola formularza eksponatu (nazwa, producent, model, opis itd.)
- Bearer token w nagłówku autoryzacji każdego żądania

**Apka nie wysyła nic** do twórców, do third-party SDK, do serwerów analitycznych
ani reklamowych.

## Co backend robi z Twoimi danymi

Backend to oprogramowanie open-source które **stawiasz sam** na własnym serwerze
— jest poza kontrolą twórców tej apki. Standardowo backend:

1. Zapisuje zdjęcia + metadane w **Twojej** bazie MariaDB
2. Wysyła zdjęcie do **Anthropic API** (Claude Opus) używając **Twojego**
   klucza API w celu identyfikacji eksponatu — patrz polityka prywatności
   Anthropic: https://www.anthropic.com/privacy
3. Generuje embedding obrazu (CLIP) lokalnie i zapisuje w lokalnej bazie LanceDB
   na **Twoim** serwerze

Anthropic API to **jedyny third-party serwis** który widzi Twoje zdjęcia, i
tylko jeśli używasz funkcji „Zidentyfikuj" (z DEV mock=false). Bez „Zidentyfikuj"
zdjęcia zostają wyłącznie w Twojej infrastrukturze.

## Uprawnienia iOS

Apka prosi o:

- **Aparat (`NSCameraUsageDescription`)** — do robienia zdjęć eksponatów
- **Biblioteka zdjęć (`NSPhotoLibraryUsageDescription`)** — do wyboru zdjęć
  z roli aparatu

Oba uprawnienia są opcjonalne. Bez nich możesz nadal przeglądać eksponaty
przez Similar/Detail, jeśli backend ma dane.

## Brak third-party SDK

Apka **nie ma**:
- Firebase / Crashlytics / Sentry / inne crash-reportery
- Google Analytics / Mixpanel / inne analityki
- Reklam / mediation SDK
- Push notifications backend
- Login z Google / Apple / Facebook / etc.

Sieć łączy się **tylko** z URL który podałeś w Ustawieniach + Anthropic API
(jeśli backend tego używa po stronie serwera).

## Dzieci

Apka nie jest skierowana do dzieci poniżej 13. roku życia. Nie zbieramy
świadomie danych dzieci, bo nie zbieramy danych w ogóle.

## Zmiany polityki

Aktualna wersja jest dostępna w [PRIVACY.md w repo](../PRIVACY.md). Każda
zmiana będzie odzwierciedlona w polu "Ostatnia aktualizacja" powyżej.

## Kontakt

Twórca: Arek Bronowicki  
Email: claude@bronowicki.com  
Repo: (private; udostępniane indywidualnie)
