#!/usr/bin/env bash
# Weryfikacja AAB PRZED uploadem do Play: podpis, 16 KB page alignment .so, manifest (versionCode/targetSdk).
# Użycie: ./scripts/verify-aab.sh <plik.aab>
set -uo pipefail
AAB="${1:?użycie: verify-aab.sh <plik.aab>}"
NDK_VERSION="${NDK_VERSION:-27.2.12479018}"
case "$(uname -s)" in
    Darwin) ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"; HOST=darwin-x86_64 ;;
    Linux)  ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}";           HOST=linux-x86_64 ;;
    *)      echo "nieobsługiwany system" >&2; exit 1 ;;
esac
READELF="$ANDROID_HOME/ndk/$NDK_VERSION/toolchains/llvm/prebuilt/$HOST/bin/llvm-readelf"
RC=0

echo "== 1. Podpis (jarsigner) =="
# jarsigner przy certyfikacie self-signed kończy OSTRZEŻENIAMI po linii "jar verified." — szukaj w całym wyjściu, nie w ostatniej linii
if jarsigner -verify "$AAB" 2>/dev/null | grep -q "jar verified"; then
    echo "   OK: jar verified"
else
    echo "   ZLE: brak podpisu"; RC=1
fi

echo "== 2. Wyrównanie stron .so (LOAD align) — oczekiwane WYŁĄCZNIE 0x4000 (16 KB) =="
TMP=$(mktemp -d)
if ! unzip -q "$AAB" -d "$TMP" 'base/lib/arm64-v8a/*.so'; then
    echo "   ZLE: rozpakowanie .so z AAB nie powiodlo sie"; RC=1
fi
if ! ls "$TMP"/base/lib/arm64-v8a/*.so >/dev/null 2>&1; then
    echo "   ZLE: w AAB NIE MA ZADNEJ biblioteki .so dla arm64-v8a (pusty wynik != OK)"
    find "$TMP" -mindepth 1 -delete && rmdir "$TMP"
    exit 1
fi
ALL=$("$READELF" -l "$TMP"/base/lib/arm64-v8a/*.so | awk '/LOAD/ {print $NF}' | sort -u | tr '\n' ' ')
BAD=$("$READELF" -l "$TMP"/base/lib/arm64-v8a/*.so | awk '/^File:/ {f=$2} /LOAD/ && $NF!="0x4000" {print f}' | sort -u)
COUNT=$(ls "$TMP"/base/lib/arm64-v8a/ | wc -l | tr -d ' ')
echo "   wartości: ${ALL}(${COUNT} plików .so)"
if [[ -z "$BAD" ]]; then
    echo "   OK"
else
    echo "   ZLE (nie 16 KB):"; echo "$BAD" | sed 's/^/     /'; RC=1
fi
find "$TMP" -mindepth 1 -delete && rmdir "$TMP"

echo "== 3. Manifest (bundletool) =="
if command -v bundletool >/dev/null 2>&1; then
    BT="bundletool"
elif [[ -f "$HOME/.local/bin/bundletool.jar" ]]; then
    BT="java -jar $HOME/.local/bin/bundletool.jar"
else
    BT=""
fi
if [[ -n "$BT" ]]; then
    $BT dump manifest --bundle "$AAB" \
      | grep -oE '(versionCode|versionName|minSdkVersion|targetSdkVersion|compileSdkVersion|largeScreens|xlargeScreens)="[^"]*"' \
      | sed 's/^/   /'
else
    echo "   ZLE: brak bundletool — manifest NIESPRAWDZONY (brak sprawdzenia != OK)"
    echo "        zainstaluj: brew install bundletool  /  jar do ~/.local/bin/bundletool.jar"
    RC=1
fi

echo "== 4. Biblioteki, ktorych brak wywala apke dopiero w RUNTIME =="
# Styl QtQuick Controls rozstrzyga sie przy uruchomieniu, nie przy kompilacji: build i podpis
# przechodza, a apka pada u uzytkownika. Basic jest OBOWIAZKOWY — Fusion importuje go wprost
# (qmldir: "import QtQuick.Controls.Basic auto"), a StackView istnieje WYLACZNIE w Basic.
REQUIRED_LIBS=(
    libInwentaryzacjaMobile_arm64-v8a.so
    libQt6Core_arm64-v8a.so
    libQt6Gui_arm64-v8a.so
    libQt6Qml_arm64-v8a.so
    libQt6Quick_arm64-v8a.so
    libQt6Network_arm64-v8a.so
    libQt6QuickControls2_arm64-v8a.so
    libQt6QuickControls2Impl_arm64-v8a.so
    libQt6QuickControls2Basic_arm64-v8a.so
    libQt6QuickControls2Fusion_arm64-v8a.so
    libplugins_platforms_qtforandroid_arm64-v8a.so
    libplugins_tls_qopensslbackend_arm64-v8a.so
    libplugins_imageformats_qjpeg_arm64-v8a.so
)
INAAB=$(unzip -Z1 "$AAB" 'base/lib/arm64-v8a/*.so' 2>/dev/null | xargs -n1 basename 2>/dev/null)
MISSING=""
for lib in "${REQUIRED_LIBS[@]}"; do
    grep -qx "$lib" <<<"$INAAB" || MISSING+="     $lib"$'\n'
done
if [[ -z "$MISSING" ]]; then
    echo "   OK: wszystkie ${#REQUIRED_LIBS[@]} wymaganych bibliotek w pakiecie"
else
    echo "   ZLE: brakuje bibliotek wymaganych do uruchomienia:"; printf '%s' "$MISSING"; RC=1
fi

exit $RC
