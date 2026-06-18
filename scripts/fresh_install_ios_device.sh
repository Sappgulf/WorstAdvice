#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
CONFIGURATION="${CONFIGURATION:-Debug}"
XCODE_DEVICE_ID="${XCODE_DEVICE_ID:-${DEVICE_UDID:-00008140-001404583444801C}}"
INSTALL_DEVICE_ID="${INSTALL_DEVICE_ID:-${CORE_DEVICE_ID:-$XCODE_DEVICE_ID}}"
BUNDLE_ID="${BUNDLE_ID:-com.worstadvice.app}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.build/DeviceInstall}"
JSON_OUTPUT_DIR="${JSON_OUTPUT_DIR:-$PWD/.build/device-install}"

mkdir -p "$DERIVED_DATA_PATH" "$JSON_OUTPUT_DIR"

node scripts/check_project_sources.js

echo "Building $SCHEME for device: $XCODE_DEVICE_ID"
xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS,id=$XCODE_DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/Badvice.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle was not produced: $APP_PATH" >&2
  exit 1
fi

echo "Uninstalling existing $BUNDLE_ID from device, if present"
xcrun devicectl device uninstall app \
  --device "$INSTALL_DEVICE_ID" \
  "$BUNDLE_ID" \
  --timeout 60 \
  --json-output "$JSON_OUTPUT_DIR/uninstall.json" >/dev/null 2>&1 || true

echo "Installing fresh build: $APP_PATH"
xcrun devicectl device install app \
  --device "$INSTALL_DEVICE_ID" \
  "$APP_PATH" \
  --timeout 120 \
  --json-output "$JSON_OUTPUT_DIR/install.json"

echo "Launching $BUNDLE_ID"
xcrun devicectl device process launch \
  --device "$INSTALL_DEVICE_ID" \
  --terminate-existing \
  "$BUNDLE_ID" \
  --timeout 60 \
  --json-output "$JSON_OUTPUT_DIR/launch.json"

echo "Fresh install complete on device: $INSTALL_DEVICE_ID"
