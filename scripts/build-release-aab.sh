#!/usr/bin/env bash
# Build signed release AAB dla Google Play.
#
# Wymagania:
#   - keystore w ~/keystores/inwentaryzacja-mobile.jks (NIE w repo)
#   - alias 'inwentaryzacja' (zgodny z keytool -genkey -alias)
#   - hasła zapisane w password managerze
#
# Hasło NIE jest brane z env ani argumentów CLI — skrypt prompt'uje
# interaktywnie żeby unikać wycieków do shell history / transcriptów.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/android-app"
BUILD_DIR="$APP_DIR/build-android-release"
KEYSTORE="${INW_KEYSTORE_PATH:-$HOME/keystores/inwentaryzacja-mobile.jks}"
ALIAS="${INW_KEYSTORE_ALIAS:-inwentaryzacja}"

if [[ ! -f "$KEYSTORE" ]]; then
    echo "ERROR: keystore nie znaleziony: $KEYSTORE" >&2
    echo "Wygeneruj przez:  keytool -genkey -v -keystore $KEYSTORE -alias $ALIAS -keyalg RSA -keysize 4096 -validity 25000" >&2
    exit 1
fi

# Toolchain
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/27.2.12479018}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
QT_ROOT="${QT_ROOT:-$HOME/Qt/6.9.3}"

# Hasła interaktywnie
read -rsp "Keystore password: " STORE_PASS
echo
read -rsp "Key password (ENTER = same): " KEY_PASS
echo
KEY_PASS="${KEY_PASS:-$STORE_PASS}"

export QT_ANDROID_KEYSTORE_PATH="$KEYSTORE"
export QT_ANDROID_KEYSTORE_ALIAS="$ALIAS"
export QT_ANDROID_KEYSTORE_STORE_PASS="$STORE_PASS"
export QT_ANDROID_KEYSTORE_KEY_PASS="$KEY_PASS"

# Configure (Release type) — re-configure ZAWSZE, bo CMake musi zobaczyć
# QT_ANDROID_KEYSTORE_PATH env var (auto-włącza QT_ANDROID_SIGN_AAB w CMakeLists.txt)
"$QT_ROOT/android_arm64_v8a/bin/qt-cmake" \
    -S "$APP_DIR" -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="$QT_ROOT/gcc_64" \
    -DQT_ANDROID_SIGN_AAB=ON \
    -DQT_ANDROID_SIGN_APK=ON

# Build signed AAB
echo "=== Building signed AAB (CMake target 'aab') ==="
cmake --build "$BUILD_DIR" -j 4 --target aab

AAB_PATH="$BUILD_DIR/android-build/build/outputs/bundle/release/android-build-release.aab"
if [[ -f "$AAB_PATH" ]]; then
    echo
    echo "✓ AAB: $AAB_PATH ($(du -h "$AAB_PATH" | cut -f1))"
    echo "  Upload do: https://play.google.com/console → Internal Testing → Create new release"
else
    echo "ERROR: AAB nie powstał. Sprawdź logi powyżej." >&2
    exit 1
fi

# Wyczyść env z hasłami (nie zostawiamy w shell session)
unset QT_ANDROID_KEYSTORE_STORE_PASS QT_ANDROID_KEYSTORE_KEY_PASS STORE_PASS KEY_PASS
