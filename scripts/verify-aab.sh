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
if jarsigner -verify "$AAB" | tail -1 | grep -q "jar verified"; then
    echo "   OK: jar verified"
else
    echo "   ZLE: brak podpisu"; RC=1
fi

echo "== 2. Wyrównanie stron .so (LOAD align) — oczekiwane WYŁĄCZNIE 0x4000 (16 KB) =="
TMP=$(mktemp -d)
unzip -q "$AAB" -d "$TMP" 'base/lib/arm64-v8a/*.so'
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
    echo "   (brak bundletool — zainstaluj: brew install bundletool / jar do ~/.local/bin/bundletool.jar)"
fi
exit $RC
