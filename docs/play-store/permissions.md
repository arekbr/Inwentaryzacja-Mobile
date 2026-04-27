---
title: Sensitive permissions — uzasadnienia
permalink: /play-store/permissions/
---

# Sensitive permissions (App content → Sensitive permissions and APIs)

Google Play od 2024 wymaga uzasadnienia każdego sensitive permission w aplikacji. Aplikacja prosi o **dwa** uprawnienia: `CAMERA` (sensitive) i `INTERNET` (normal — bez justification).

---

## CAMERA — Camera

**Pole: Why does your app need to request CAMERA?**

```
Aplikacja deleguje przechwytywanie zdjęcia do systemowej aplikacji aparatu (Google Camera) przez Intent ACTION_IMAGE_CAPTURE — żeby uzyskać pełną jakość Pixela (HDR+, Night Sight, multi-frame processing). Uprawnienie CAMERA jest wymagane przez systemową bibliotekę intent broker — bez niego niektóre wersje Androida automatycznie odrzucają wywołanie systemowej kamery z powodu cofniętych uprawnień. Aplikacja nie czyta z aparatu samodzielnie i nie nagrywa wideo.
```

---

## Czego NIE prosi (a czego konkurencja często prosi)

Lista permissions które aplikacja **świadomie nie deklaruje** w `AndroidManifest.xml` — żeby uniknąć fałszywego sygnału w Data Safety i u użytkowników:

| Permission | Powód braku |
|---|---|
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | aplikacja nie potrzebuje GPS — eksponaty mają pole „Miejsce" wpisane ręcznie |
| `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` | apka pisze tylko do `getExternalFilesDir()` — własny sandbox, bez globalnego storage permission |
| `READ_MEDIA_IMAGES` (Android 13+) | apka nie przegląda galerii — robi nowe zdjęcia przez Camera Intent |
| `RECORD_AUDIO` | brak nagrywania |
| `READ_CONTACTS` / `WRITE_CONTACTS` | brak kontaktów |
| `BLUETOOTH*` | brak BT |
| `POST_NOTIFICATIONS` | apka nie wysyła notyfikacji |
| `FOREGROUND_SERVICE` | brak background services |
| `ACCESS_BACKGROUND_LOCATION` | apka nie działa w tle |

Brak tych permission w manifeście oznacza że Play Store nie pyta o ich uzasadnienie — czyste i szybkie review.

---

## Internet permission — niewymagane uzasadnienie

`INTERNET` to "normal" permission Androida — Play Console nie wymaga osobnego justification. W polityce prywatności (sekcja 5) wystarczy wzmianka że apka łączy się TYLKO z URL wpisanym przez użytkownika.
