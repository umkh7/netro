#!/usr/bin/env bash
# Собирает ядро Xray (libXray, MIT; Xray-core, MPL-2.0) для Android и кладёт AAR в проект.
# Нужны: Go, Python 3, Android SDK + NDK (ANDROID_HOME, ANDROID_NDK_HOME).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$ROOT/.deps}"
LIBXRAY_REF="${LIBXRAY_REF:-main}"
mkdir -p "$WORK"
if [ ! -d "$WORK/libXray" ]; then
  git clone --depth 1 -b "$LIBXRAY_REF" https://github.com/XTLS/libXray "$WORK/libXray"
fi
cd "$WORK/libXray"
LIBXRAY_ANDROID_API=24 python3 build/main.py android
mkdir -p "$ROOT/app/android/app/libs"
cp libXray.aar "$ROOT/app/android/app/libs/libXray.aar"
echo "OK: app/android/app/libs/libXray.aar"
