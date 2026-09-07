#!/usr/bin/env bash
# Build podpisanego AAB (Google Play) — Qt 6.11 Android, arm64-v8a.
#
# Użycie:
#   ./scripts/build-release-aab.sh                 # pyta o hasło keystore (bez echa)
#   printf '%s' "$PASS" | ./scripts/build-release-aab.sh   # hasło ze stdin (np. z managera haseł, bez echa)
#
# Zmienne opcjonalne:
#   INW_KEYSTORE_PATH   (domyślnie ~/keystores/inwentaryzacja-mobile.jks)
#   INW_KEYSTORE_ALIAS  (domyślnie inwentaryzacja)
#   QT_ROOT             (domyślnie ~/Qt/6.11.2)
#   ANDROID_HOME / ANDROID_NDK_ROOT / JAVA_HOME — wykrywane per system (macOS / Linux), można nadpisać
#
# Landmine Qt 6.9+: podpis AAB działa TYLKO gdy -DQT_ANDROID_SIGN_AAB=ON idzie jako flaga
# configure (sam env var QT_ANDROID_KEYSTORE_* lub target property to za mało).
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

# --- Toolchain per system ---
NDK_VERSION="${NDK_VERSION:-27.2.12479018}"     # Qt 6.10/6.11: NDK r27c (r28+ niewspierane oficjalnie)
QT_ROOT="${QT_ROOT:-$HOME/Qt/6.11.2}"
case "$(uname -s)" in
    Darwin)
        export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
        export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || echo /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home)}"
        QT_HOST_DIR="${QT_HOST_DIR:-$QT_ROOT/macos}"
        ;;
    Linux)
        export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
        export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
        QT_HOST_DIR="${QT_HOST_DIR:-$QT_ROOT/gcc_64}"
        ;;
    *)  echo "ERROR: nieobsługiwany system $(uname -s)" >&2; exit 1 ;;
esac
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$ANDROID_HOME/ndk/$NDK_VERSION}"

for d in "$ANDROID_HOME" "$ANDROID_NDK_ROOT" "$JAVA_HOME" "$QT_HOST_DIR" "$QT_ROOT/android_arm64_v8a"; do
    [[ -d "$d" ]] || { echo "ERROR: brak katalogu: $d" >&2; exit 1; }
done

echo "=== Toolchain ==="
echo "  Qt:   $QT_ROOT (host: $QT_HOST_DIR)"
echo "  NDK:  $ANDROID_NDK_ROOT"
echo "  JDK:  $JAVA_HOME"
echo "  SDK:  $ANDROID_HOME"

# --- Hasła (bez echa; ze stdin, jeśli nie jest terminalem) ---
if [[ -t 0 ]]; then
    read -rsp "Keystore password: " STORE_PASS; echo
    read -rsp "Key password (ENTER = same): " KEY_PASS; echo
else
    IFS= read -r STORE_PASS || true
    IFS= read -r KEY_PASS || true
fi
KEY_PASS="${KEY_PASS:-$STORE_PASS}"
[[ -n "$STORE_PASS" ]] || { echo "ERROR: puste hasło keystore" >&2; exit 1; }

export QT_ANDROID_KEYSTORE_PATH="$KEYSTORE"
export QT_ANDROID_KEYSTORE_ALIAS="$ALIAS"
export QT_ANDROID_KEYSTORE_STORE_PASS="$STORE_PASS"
export QT_ANDROID_KEYSTORE_KEY_PASS="$KEY_PASS"

echo "=== Configure (Release, signed AAB) ==="
"$QT_ROOT/android_arm64_v8a/bin/qt-cmake" \
    -S "$APP_DIR" -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH="$QT_HOST_DIR" \
    -DQT_ANDROID_SIGN_AAB=ON \
    -DQT_ANDROID_SIGN_APK=ON

echo "=== Building signed AAB (CMake target 'aab') ==="
cmake --build "$BUILD_DIR" -j "${JOBS:-4}" --target aab

AAB_PATH="$BUILD_DIR/android-build/build/outputs/bundle/release/android-build-release.aab"
if [[ -f "$AAB_PATH" ]]; then
    echo
    echo "✓ AAB: $AAB_PATH ($(du -h "$AAB_PATH" | cut -f1))"
    echo "  Weryfikacja: ./scripts/verify-aab.sh \"$AAB_PATH\""
    echo "  Upload: https://play.google.com/console → Produkcja → Utwórz nową wersję"
else
    echo "ERROR: AAB nie powstał. Sprawdź logi powyżej." >&2
    exit 1
fi

unset QT_ANDROID_KEYSTORE_STORE_PASS QT_ANDROID_KEYSTORE_KEY_PASS STORE_PASS KEY_PASS
