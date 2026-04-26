# Inwentaryzacja-Mobile

Mobilna apka (Qt 6 Android) do katalogowania eksponatów muzeum retro-computingu **w terenie**. Zdjęcie eksponatu → AI Claude rozpoznaje co to → szybka edycja → zapis do wspólnej bazy MariaDB. Bonus: **wyszukiwanie podobnych** przez CLIP+LanceDB embedding similarity.

Siostrzana apka desktopowa: [arekbr/Inwentaryzacja](https://github.com/arekbr/Inwentaryzacja) — wspólna baza, wspólny model danych, ten sam projekt.

![Status](https://img.shields.io/badge/status-WIP%20active-orange)
![Qt](https://img.shields.io/badge/Qt-6.9-green)
![Android](https://img.shields.io/badge/Android-15+-blue)
![License](https://img.shields.io/badge/license-MIT-brightgreen)

## Po co to wszystko?

Mam ~1870 eksponatów w bazie (Amigi, Atari, Commodore, ZX, early IBM PC, konsole 8/16 bit, klawiatury, joye, kable, dziwactwa). Desktop działa od dawna — siedzę przed kompem, mam czas, wpisuję ręcznie. Ale **w terenie** (giełda, znajomy z piwnicą starego sprzętu, przypadkowo znaleziony skarb) — desktop to przeszkoda.

Telefon. Foto. AI mówi "to Amiga 1200". Ja zatwierdzam (lub poprawiam jeśli AI źle). Zapisane.

Plus: gdy widzę coś znajomego ale nie pewnego — "znajdź podobne" → galeria 5 najbliższych z mojej bazy → "aha, to jest jak ten sprzęt który już mam, tylko inny model". Idealne dla zbieracza retro.

## Architektura

```
[Pixel 10 Pro]  ──HTTPS──▶  [FastAPI backend]  ──▶  [MariaDB `zbiory`]
   Qt 6 Android                  │
                                 ├─ Claude Opus 4.7 (vision: identyfikacja)
                                 └─ CLIP + LanceDB (similarity search 1870 eksp.)
```

**Apka Qt:** Camera Intent (Pixel HDR+/Night Sight przez JNI, NIE QtMultimedia), formularz z wynikami AI, lista podobnych z miniaturami, przeglądanie bazy.

**Backend FastAPI:** orkiestruje wywołania Claude, oblicza CLIP embeddingi, szuka podobnych w LanceDB, zapisuje do MariaDB. Reużywa `Artefakt` Pydantic model z [muzeum-inwentarz](https://github.com/arekbr/muzeum-inwentarz) (offline AI pipeline) — jedno źródło prawdy schematu.

**Baza:** ta sama `zbiory` co desktop. Zmiany w mobile widać w desktopie i odwrotnie.

## Stan dzisiaj (kwiecień 2026)

✅ **Działa:**
- Camera Intent + AI identyfikacja (Claude Opus 4.7, mock w dev)
- Edycja eksponatu (pola Artefakt + meta) + zapis do MariaDB (multipart upload)
- Wyszukiwanie podobnych (CLIP + LanceDB, top 5 z miniaturami)
- Przeglądanie bazy (lista alfabetyczna z paginacją + lazy thumbnails)
- Szczegóły eksponatu (markdown render opisu)
- Welcome screen z auto-refresh stanu backendu
- **Security tier-1.5:** auth bearer token, rate limiting (slowapi), validate image MIME + magic bytes + decomp bomb, security headers, prod hardening (docs off, no DEV_MOCK)
- **Audit qt-cpp + qt-qml zaliczony** — 9 PRów P1/P2, raport `docs/audit-2026-04-25.md`

⏳ **W toku:**
- Uniwersalne request tokeny (UUID per request, filter w QML — Q-05 audit fix)
- UX prompt 401 + auto-nav do Settings (token API expired)

🔜 **Plan:**
- Deploy backendu na hosting publiczny (do tej pory tylko mak Studio + carbon Linux dev)
- AAB + Google Play Internal Testing (5 testerów)
- "Dopisz opis AI" — port flow z desktopowej v1.5 (Anthropic enrichment) na mobilkę

## Stack

| Co | Wersja |
|---|---|
| Qt | 6.9.x (Android: arm64_v8a) |
| C++ | 17 |
| Build | CMake + qt-cmake (Android wrapper) |
| Backend | FastAPI 0.x + uvicorn + slowapi |
| AI | Anthropic Claude Opus 4.7 (z `output_format=Artefakt`) |
| Similarity | CLIP (open_clip) + LanceDB |
| Baza | MariaDB 12 (przez PyMySQL) |
| Android NDK | 27.2.12479018 |
| Java | OpenJDK 21 (build tools) |

## Build (CLI, bez Qt Creator)

**Carbon (Linux dev):**
```bash
export ANDROID_HOME=~/Android/Sdk ANDROID_SDK_ROOT=~/Android/Sdk
export ANDROID_NDK_ROOT=~/Android/Sdk/ndk/27.2.12479018
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

cd android-app
~/Qt/6.9.3/android_arm64_v8a/bin/qt-cmake -S . -B build-android-arm64 -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug -DQT_HOST_PATH=$HOME/Qt/6.9.3/gcc_64
cmake --build build-android-arm64 -j 4

~/Android/Sdk/platform-tools/adb install -r \
  build-android-arm64/android-build/build/outputs/apk/debug/android-build-debug.apk
~/Android/Sdk/platform-tools/adb shell monkey -p com.bronkibrothers.inwentaryzacja.mobile \
  -c android.intent.category.LAUNCHER 1
```

Czas builda: ~1m30s, APK: ~75 MB. Dla mac-a (Apple Silicon) analogicznie z Qt macos build.

## Backend (lokalnie do dev)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env  # uzupełnij MariaDB credentials + ANTHROPIC_API_KEY
# ENVIRONMENT=development włącza mock AI (DEV_MOCK_IDENTIFY=true) — bez kosztów Anthropic

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

W apce: Settings → URL backendu → `http://twoj-host:8000` + token API jeśli wymagany.

## Testy

**Backend:**
```bash
cd backend && pytest -v  # 27 testów security smoke + multipart + similarity
```

**Apka:** smoke test ręczny po każdym build (pattern z memory `feedback_android_test_loop.md`):
```bash
adb install -r ... && adb shell am start ... && adb logcat -d | grep -E "ApiClient|fatal"
```

## Konwencje

- **Workflow git:** `feature/* → dev → main`. Nigdy bezpośrednio do main.
- **Multi-device sync:** carbon + mak + debianJD. PRZED pracą `git fetch origin --prune` + sanity check `git ls-remote` vs `git log origin/X`.
- **Język:** kod + nazwy techniczne po angielsku, komentarze + UI + dokumentacja po polsku. Bez korpobełkotu w UI ("don't ask again" → "nie pytaj ponownie").
- **AI generation:** kod tworzony z pomocą Claude / ChatGPT / GROK — credit zachowany.

## Dlaczego AI?

Bo to przyszłość, a ja lubię testować granice. Claude, ChatGPT i GROK piszą kod szybciej, niż ja nadążam sprawdzać. To jak mieć zespół programistów w kieszeni — tylko czasem trzeba ich poprawić. 😄 Eksperyment trwa, a apka działa i ma się dobrze.

Sam jestem **„marnym programistą"** (doba ma 24 godziny, dzień pracy zwykle wypełnia administracja IT, retro hobby, malarstwo i muzyka — kodowanie to wieczory) — bez AI ten projekt zająłby kilka lat. Z AI zajmuje miesiące.

## Powiązane projekty

- 🖥 **Desktop:** [arekbr/Inwentaryzacja](https://github.com/arekbr/Inwentaryzacja) — Qt Widgets, ten sam schemat bazy
- 🐍 **Offline AI pipeline:** [arekbr/muzeum-inwentarz](https://github.com/arekbr/muzeum-inwentarz) (jeśli publikowany) — Python batch AI dla istniejących zdjęć
- 📷 **Zbiory:** ~1870 eksponatów retro-computingu, foto z Pixela, baza MariaDB

## Podziękowania

Wirtualne ukłony dla **Claude**, **ChatGPT** i **GROK** — bez nich ten kod by nie powstał!  
Plus dla **Qt**, **FastAPI**, **Anthropic**, **MariaDB**, **CLIP/OpenCLIP**, **LanceDB** za napędzanie tego projektu.

Demoscene Samar Productions, retro społeczność polska — dzięki za wszystkie znajomości i sprzęt który "musisz mieć w kolekcji".

## Licencja

MIT — patrz [`LICENSE`](LICENSE). Rób co chcesz, byle wzmianka o autorze została. Krótko i bez prawników.

---

**Autor:** Yugorin (Arek Bronowicki, GitHub: arekbr) · arek@bronowicki.com  
**Stan:** WIP active · kwiecień 2026 · sole maintainer
