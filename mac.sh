#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/apps/ios/LutShop.xcodeproj"
SCHEME="LutShop"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/LutShop.app"
BUNDLE_ID="com.lutshop.app"
PREFERRED_DEVICE="${LUT_SHOP_DEVICE:-}"

usage() {
  cat <<'USAGE'
Usage:
  ./mac.sh                 Build, install, and launch on an iPhone simulator
  ./mac.sh --build-only    Only build the iOS simulator app

Optional environment:
  LUT_SHOP_DEVICE="iPhone 17 Pro" ./mac.sh
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

BUILD_ONLY=0
if [[ "${1:-}" == "--build-only" ]]; then
  BUILD_ONLY=1
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command xcodebuild
require_command xcrun

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Cannot find Xcode project: $PROJECT_PATH" >&2
  exit 1
fi

echo "==> Building lut-shop iOS simulator app"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ "$BUILD_ONLY" == "1" ]]; then
  echo "==> Build complete: $APP_PATH"
  exit 0
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build finished, but app bundle was not found: $APP_PATH" >&2
  exit 1
fi

booted_device_id() {
  xcrun simctl list devices booted |
    sed -nE 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/p' |
    head -n 1
}

available_device_id_named() {
  local name="$1"
  xcrun simctl list devices available |
    sed -nE "/$name/s/.*\\(([0-9A-Fa-f-]{36})\\).*/\\1/p" |
    head -n 1
}

DEVICE_ID="$(booted_device_id)"

if [[ -z "$DEVICE_ID" ]]; then
  if [[ -n "$PREFERRED_DEVICE" ]]; then
    DEVICE_ID="$(available_device_id_named "$PREFERRED_DEVICE")"
  fi

  if [[ -z "$DEVICE_ID" ]]; then
    for name in "iPhone 17 Pro" "iPhone 16 Pro" "iPhone 15 Pro" "iPhone 14 Pro"; do
      DEVICE_ID="$(available_device_id_named "$name")"
      if [[ -n "$DEVICE_ID" ]]; then
        break
      fi
    done
  fi
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "Could not find an available iPhone simulator. Open Xcode and install an iOS simulator runtime first." >&2
  exit 1
fi

echo "==> Booting simulator $DEVICE_ID"
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b

echo "==> Installing $APP_PATH"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

echo "==> Launching $BUNDLE_ID"
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "==> lut-shop is running on simulator $DEVICE_ID"
