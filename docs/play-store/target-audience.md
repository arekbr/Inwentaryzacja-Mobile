---
title: Target Audience and Content
permalink: /play-store/target-audience/
---

# Target Audience and Content (App content → Target audience)

Google Play wymaga zadeklarowania docelowej grupy wiekowej. Obowiązują **rygorystyczne reguły** dla aplikacji skierowanych do dzieci (Designed for Families program).

---

## Pytanie: Target age group

**Zaznacz tylko: `18 and over` (lub jeśli wolisz szerzej: `13–17` + `18 and over`)**

Uzasadnienie: aplikacja jest dla **kolekcjonerów retro-computingu** — niche dla dorosłych pasjonatów i częściowo nastolatków zainteresowanych historią komputerów. Apka nie jest grą, nie ma elementów rozrywkowych, wymaga uruchomienia własnego serwera (technical entry barrier).

**NIE zaznaczaj** `Ages 5 and under`, `Ages 6–8`, `Ages 9–12` — to wymuszałoby spełnienie Designed for Families program (rygorystyczne reguły reklam, brak Anthropic API, dodatkowe certyfikacje).

---

## Pytanie: Czy aplikacja przyciąga dzieci?

**Odpowiedź: No**

Uzasadnienie:
- temat (retro-computing) jest niche dla pasjonatów
- ikona to pixel-art retro komputera (nie kreskówka)
- nie ma elementów grywalizacji, postaci, gry
- nie ma jasnych kolorów, animacji, dźwięków przyciągających dzieci
- wymaga konfiguracji własnego backendu (technical setup)

---

## Pytanie: Czy aplikacja zawiera reklamy?

**Odpowiedź: No**

Brak SDK reklamowych (AdMob, Unity Ads, IronSource, AppLovin), brak interstitials, brak banner-ów, brak rewarded video. Aplikacja nie ma żadnych SDK reklamowych w binary — to można potwierdzić przez `bundletool` analiza zależności AAB.

---

## Po publikacji

Jeśli zmienisz target age (np. obniżysz do 13+ żeby trafić do młodszych pasjonatów retro), Google może wymusić ponowną walidację Data Safety form i Content Rating. Zacznij konserwatywnie (`18+`), rozluźniaj jeśli dane analytics Play Console pokazują młodszych użytkowników.
