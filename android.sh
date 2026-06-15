#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$ROOT_DIR/apps/android"
APK="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
PACKAGE_NAME="com.lutshop"

cd "$ANDROID_DIR"
./gradlew :app:assembleDebug

if ! command -v adb >/dev/null 2>&1; then
  echo "Build complete. adb not found, skipping install."
  exit 0
fi

if ! adb get-state >/dev/null 2>&1; then
  echo "Build complete. No Android device or emulator detected, skipping install."
  exit 0
fi

adb install -r "$APK"
adb shell monkey -p "$PACKAGE_NAME" 1
