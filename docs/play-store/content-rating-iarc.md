---
title: Content Rating (IARC) — odpowiedzi
permalink: /play-store/content-rating-iarc/
---

# Content Rating questionnaire (IARC)

Google Play używa kwestionariusza **IARC** (International Age Rating Coalition) — jeden raz wypełniasz, dostajesz oceny dla wszystkich rynków (PEGI, ESRB, USK, Russia, Brazylia).

---

## Krok 1: Email kontaktowy

```
dev@bronkibrothers.com
```

## Krok 2: Kategoria aplikacji

**Wybór:** `All other app types` (nie gra, nie dating, nie social, nie shopping)

---

## Krok 3: Pytania kwestionariusza

Aplikacja jest narzędziem do katalogowania kolekcji prywatnych. Brak treści użytkowników, brak komentarzy, brak chat-u, brak elementów gry. Odpowiedzi:

| Pytanie | Odpowiedź |
|---|---|
| Does your app contain any references to or content involving violence? | **No** |
| Does your app contain any sexual material? | **No** |
| Does your app reference, contain, or simulate gambling? | **No** |
| Does your app contain any references to or content involving alcohol, tobacco, or drugs? | **No** |
| Does your app contain any references to crude humor or fear? | **No** |
| Does your app share user-generated content with third parties? | **No** (dane idą TYLKO do user-supplied backend, nie do społeczności) |
| Does your app allow users to communicate, share, or exchange user-generated content? | **No** (brak chat, brak forum, brak komentarzy, brak share-to-other-users) |
| Does your app share or allow users to share their location with other users? | **No** (brak permission lokalizacji w ogóle) |
| Does your app contain digital purchases? | **No** |
| Does your app allow users to purchase, win, or trade physical or virtual goods? | **No** |
| Does your app contain advertising? | **No** |
| Does your app contain web browser? | **No** (apka tylko HTTP request do user-konfigurowanego URL backendu, nie general-purpose browser) |

---

## Krok 4: Spodziewany rating

Po tych odpowiedziach IARC wystawia:

- **PEGI 3** (Polska / Europa)
- **ESRB Everyone** (USA)
- **USK 0** (Niemcy)
- **IARC Everyone** (świat)

Czyli: brak ograniczeń wiekowych, dostępne dla każdego.

---

## Po wypełnieniu

Po zakończeniu kwestionariusza Google generuje certyfikat IARC z unikalnym ID. Trzymaj kopię w razie sporu o rating w przyszłości.
