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

**Hasła w password managerze** (Bitwarden / 1Password). Backup haseł osobno od pliku keystore.

### 2. Google Play App Signing (zalecane)

Przy pierwszym uploadzie AAB do Play Console:
- Włącz **Play App Signing** (default w 2026)
- Google trzyma „final signing key" w swoim KMS
- Twój `.jks` staje się **upload key** (rotatable przez Play support)
- Bezpieczeństwo: Twój klucz wyciekł → Play support pomoże rotate, apka nadal aktualizowalna

## Build signed AAB

```bash
./scripts/build-release-aab.sh
```

Skrypt:
1. Pyta o hasło keystore (bez echo)
2. Pyta o hasło klucza (ENTER = takie samo jak keystore — domyślne)
3. Eksportuje `QT_ANDROID_KEYSTORE_*` env vars
4. `qt-cmake` configure (Release type) jeśli pierwszy raz
5. `cmake --build --target aab` → signed AAB
6. Czyści env z hasłami

Wynikowy plik: `android-app/build-android-release/android-build/build/outputs/bundle/release/android-build-release.aab`

## Versioning

Przy każdym release **bump** w `android-app/CMakeLists.txt`:
```cmake
project(InwentaryzacjaMobile VERSION 0.1.1 ...)         # versionName
set_target_properties(InwentaryzacjaMobile PROPERTIES
    QT_ANDROID_VERSION_CODE 2                           # ≥ poprzedniego!
    QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
)
```

`versionCode` **musi** rosnąć monotonicznie z każdym uploadem do Play (nawet jeśli versionName się powtarza).

## Upload do Play Console

1. Zaloguj się: https://play.google.com/console
2. Wybierz aplikację (przy pierwszym uploadzie utwórz nową)
3. **Internal Testing** track → Create new release
4. Upload AAB → Google waliduje signature + Play App Signing setup
5. Release notes: krótki tekst (PL i EN)
6. Roll-out percentage: 100% (Internal testing zawsze)
7. Save → Review release → Start rollout

Przy pierwszym release Play Console poprosi o:
- App content (privacy policy URL, content rating, target audience, ads, data safety)
- Store listing (icon 512×512, screenshots, descriptions, feature graphic 1024×500)

Patrz `docs/PLAY_STORE_SETUP.md` (TODO).

## Mała checklista przed `git tag`

- [ ] `versionCode` zwiększony
- [ ] `versionName` zwiększony semver
- [ ] `CHANGELOG.md` zaktualizowany
- [ ] PR `dev → main` zmergowany
- [ ] Build signed AAB lokalnie (`./scripts/build-release-aab.sh`)
- [ ] Test fizyczny na Pixelu — install AAB → odpal → smoke test (`bundletool` może wygenerować APKs z AAB)
- [ ] Upload do Play Internal Testing
- [ ] `git tag v0.1.1 && git push origin v0.1.1`
