---
title: Data Safety form — odpowiedzi
permalink: /play-store/data-safety/
---

# Data Safety form (App content → Data safety)

Google Play wymaga zadeklarowania jak aplikacja postępuje z danymi użytkowników. Aplikacja jest **dumb client** — sam autor nic nie zbiera, ale dane technicznie wychodzą z urządzenia gdy użytkownik świadomie skonfiguruje backend i kliknie przycisk. Poniżej **rygorystycznie konserwatywna** deklaracja, która przejdzie review.

---

## Sekcja 1: Czy aplikacja zbiera lub udostępnia jakiekolwiek wymagane typy danych?

**Odpowiedź: Tak**

Uzasadnienie: aplikacja przesyła zdjęcia eksponatów do backendu wskazanego przez użytkownika w Ustawieniach. Mimo że autor aplikacji nie kontroluje destynacji, formalnie dane „opuszczają urządzenie" — Google wymaga zadeklarowania.

---

## Sekcja 2: Czy wszystkie dane użytkownika zebrane przez aplikację są szyfrowane podczas przesyłania?

**Odpowiedź: Tak (z zastrzeżeniem)**

Aplikacja używa standardowych mechanizmów Qt Network — jeśli użytkownik wpisze URL backendu zaczynający się od `https://`, transfer jest szyfrowany TLS. Aplikacja akceptuje też `http://` (bo użytkownik może mieć backend w sieci lokalnej / WireGuard tunnel — wtedy szyfrowanie idzie warstwą niżej).

---

## Sekcja 3: Czy zapewniasz użytkownikom mechanizm żądania usunięcia ich danych?

**Odpowiedź: Tak**

Użytkownik może:
- usunąć aplikację z urządzenia (kasuje token i URL z `QSettings`)
- skontaktować się z **operatorem swojego backendu** (nie z autorem aplikacji) w celu usunięcia danych z bazy MariaDB

URL do polityki: `https://arekbr.github.io/Inwentaryzacja-Mobile/privacy/`

---

## Sekcja 4: Typy danych zbieranych — **TYLKO gdy użytkownik konfiguruje backend i klika przycisk**

### ✅ Photos and videos → Photos

| Pole | Wartość |
|---|---|
| Is this data collected, shared, or both? | **Collected** (operator backendu zapisuje do bazy) |
| Optional or required? | **Optional** — użytkownik decyduje czy klika „Zidentyfikuj" / „Zapisz do bazy" |
| Why is data collected? | **App functionality** — katalogowanie eksponatów |
| Is this data processed ephemerally? | **No** — operator backendu zapisuje na stałe (to jest cel apki) |

### ❌ NIE zaznaczaj nic z poniższych

- Personal info (name, email, phone, address) — **nie zbieramy**
- Financial info — **nie**
- Health and fitness — **nie**
- Messages — **nie**
- Audio files — **nie**
- Files and docs — **nie** (tylko foto)
- Calendar — **nie**
- Contacts — **nie**
- App activity / search history / installed apps — **nie**
- Web browsing — **nie**
- App info / device or other IDs — **nie** (`allowBackup=false`, brak AAID/Firebase/GA)
- Location — **nie** (brak fine/coarse, brak permission ACCESS_*_LOCATION)

---

## Sekcja 5: Security practices — checkboxes

- ☑ **Data is encrypted in transit** (jeśli użytkownik wpisze HTTPS URL — domyślnie zalecane)
- ☑ **Users can request that their data be deleted** (przez kontakt z operatorem backendu lub deinstalację)
- ☐ Committed to follow Play Families Policy (NIE — apka nie jest dla rodzin)
- ☐ Independent security review (NIE — solo dev)

---

## Skopiowane uzasadnienie do pola „Privacy practices explanation"

```
Aplikacja jest klientem open-source bez wbudowanego serwera. Dane (zdjęcia eksponatów) są wysyłane WYŁĄCZNIE pod URL backendu wpisanego przez użytkownika w Ustawieniach, dopiero po świadomym kliknięciu przycisku "Zidentyfikuj", "Szukaj podobnych" lub "Zapisz do bazy". Autor aplikacji nie ma żadnego serwera ani dostępu do danych użytkowników. Pełna polityka prywatności: https://arekbr.github.io/Inwentaryzacja-Mobile/privacy/
```
