# Release process — Inwentaryzacja Mobile

## Wymagania jednorazowe

### 1. Keystore (raz w życiu apki)

```bash
keytool -genkey -v \
    -keystore ~/keystores/inwentaryzacja-mobile.jks \
    -alias inwentaryzacja \
    -keyalg RSA -keysize 4096 -validity 25000
chmod 600 ~/keystores/inwentaryzacja-mobile.jks
```

**Backup keystore w 3 miejscach** (utrata = brak możliwości aktualizacji apki):
- Cloud encrypted (np. Bitwarden vault file attachment)
- USB pendrive offline
- Wydrukowana kopia hex hash + alias + CN (paper backup)

**Hasło keystore w managerze haseł `bw`** — item `inwentaryzacja-mobile-keystore` (hasło klucza = hasło keystore).
Kopia haseł osobno od pliku keystore. 🔴 Bez hasła nie ma aktualizacji apki — jedyne wyjście to reset
klucza przesyłania u Google (Play App Signing jest włączony, patrz niżej).

### 1a. Historia kluczy przesyłania

| Plik | Utworzony | Stan |
|---|---|---|
| `~/keystores/inwentaryzacja-mobile.jks` | 27.04.2026 | hasło utracone (nie było w managerze haseł) — **nieużywalny** |
| `~/keystores/inwentaryzacja-mobile-2026.jks` | 07.09.2026 | hasło w `bw` (`inwentaryzacja-mobile-keystore`); certyfikat `upload-cert-2026.pem`; **wymaga zatwierdzenia resetu klucza przesyłania w Play Console** (Play App Signing → Certyfikat klucza przesyłania → Poproś o zresetowanie) |

Lekcja: hasło keystore idzie do managera haseł **w tej samej minucie**, w której powstaje plik. Bez tego plik jest bezwartościowy.

### 2. Google Play App Signing (zalecane)

Przy pierwszym uploadzie AAB do Play Console:
- Włącz **Play App Signing** (default w 2026)
- Google trzyma „final signing key" w swoim KMS
- Twój `.jks` staje się **upload key** (rotatable przez Play support)
- Bezpieczeństwo: Twój klucz wyciekł → Play support pomoże rotate, apka nadal aktualizowalna

## Build signed AAB

Toolchain (Qt 6.11.x, NDK 27.2.12479018, JDK 21) — skrypt wykrywa ścieżki per system (macOS / Linux).

```bash
./scripts/build-release-aab.sh                                                  # pyta o hasło (bez echa)
bw get password inwentaryzacja-mobile-keystore | ./scripts/build-release-aab.sh # hasło ze stdin
```

Skrypt:
1. Czyta hasło keystore z terminala (bez echa) albo ze stdin, gdy stdin nie jest terminalem
2. Hasło klucza: drugi wiersz / ENTER = takie samo jak keystore
3. Eksportuje `QT_ANDROID_KEYSTORE_*` env vars
4. `qt-cmake` configure (Release) z `-DQT_ANDROID_SIGN_AAB=ON` — **zawsze**, bo tylko flaga configure włącza podpis
5. `cmake --build --target aab` → signed AAB
6. Czyści env z hasłami

Weryfikacja przed uploadem (podpis, 16 KB page alignment wszystkich `.so`, versionCode/targetSdk z manifestu):
```bash
./scripts/verify-aab.sh android-app/build-android-release/android-build/build/outputs/bundle/release/android-build-release.aab
```

## Versioning

- `versionName` = `project(... VERSION x.y.z)` w `android-app/CMakeLists.txt` — bump ręczny (semver).
- `versionCode` = **automatycznie** `git rev-list --count HEAD + 10` (CMake). Każdy commit podnosi kod,
  więc dwa AAB-y z tego samego commita mają ten sam kod (Play odrzuci duplikat — zrób commit).
  Historia: v0.1.0 = kod 98 (30.04.2026).
- Wymogi Play (stan 2026-09): `targetSdkVersion` **36** dla każdej aktualizacji od 31.08.2026,
  16 KB page size dla targetSdk ≥ 35 (odrzucanie od 1.02.2027). Oba spięte w CMake i sprawdzane przez `verify-aab.sh`.

## Upload do Play Console

1. Zaloguj się: https://play.google.com/console
2. Wybierz aplikację (przy pierwszym uploadzie utwórz nową)
3. Track **Produkcja** (apka jest w produkcji od 05.05.2026) → Utwórz nową wersję
4. Upload AAB → Google waliduje signature + Play App Signing setup
5. Release notes: krótki tekst (PL i EN)
6. Roll-out percentage: 100% (4 instalacje — bez sensu etapować)
7. Save → Review release → Start rollout

Przy pierwszym release Play Console poprosi o:
- App content (privacy policy URL, content rating, target audience, ads, data safety)
- Store listing (icon 512×512, screenshots, descriptions, feature graphic 1024×500)

Patrz `docs/PLAY_STORE_SETUP.md` (TODO).

## Mała checklista przed `git tag`

- [ ] `versionName` zwiększony semver (`versionCode` rośnie sam z commitów)
- [ ] `CHANGELOG.md` zaktualizowany
- [ ] PR `dev → main` zmergowany
- [ ] Build signed AAB lokalnie (`./scripts/build-release-aab.sh`) + `./scripts/verify-aab.sh`
- [ ] Test fizyczny na Pixelu — install AAB → odpal → smoke test (`bundletool` może wygenerować APKs z AAB)
- [ ] Upload do Play (Produkcja) + notatki wydania z `docs/play-store/release-notes-vX.Y.Z.md`
- [ ] `git tag v0.1.1 && git push origin v0.1.1`
