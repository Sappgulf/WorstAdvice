#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SIMULATOR_ID="${SIMULATOR_ID:-47F86C58-BDC0-472D-9A4F-3AC719B015FB}"
SIMULATOR_IDS="${SIMULATOR_IDS:-$SIMULATOR_ID}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/austinbeatty/Downloads/Xcode-beta.app/Contents/Developer}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/ScreenshotModeCaptureDerivedData}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/.build/screenshots/screenshot-mode}"
SEED="${SEED:-424242}"
BUILD="${BUILD:-1}"
CAPTURE_DELAY="${CAPTURE_DELAY:-12}"
FIRST_CAPTURE_DELAY="${FIRST_CAPTURE_DELAY:-24}"
PROJECT="${PROJECT:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.worstadvice.app}"

if [[ "$#" -gt 0 ]]; then
  TABS=("$@")
else
  TABS=(generate chaosHub friends quotes favorites history settings)
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Badvice.app"
export DEVELOPER_DIR

mkdir -p "$OUTPUT_DIR"

IFS=',' read -r -a CAPTURE_SIMULATORS <<< "$SIMULATOR_IDS"
PRIMARY_SIMULATOR_ID="${CAPTURE_SIMULATORS[0]}"

device_name() {
  local simulator_id="$1"
  xcrun simctl list devices available | awk -v id="$simulator_id" '
    index($0, "(" id ")") {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+\([A-F0-9-]+\).*/, "", line)
      print line
      exit
    }
  '
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

if [[ "$BUILD" == "1" ]]; then
  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$PRIMARY_SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO
fi

for simulator_id in "${CAPTURE_SIMULATORS[@]}"; do
  simulator_id="$(printf '%s' "$simulator_id" | xargs)"
  [[ -n "$simulator_id" ]] || continue

  name="$(device_name "$simulator_id")"
  [[ -n "$name" ]] || name="$simulator_id"
  slug="$(slugify "$name")"
  if [[ "${#CAPTURE_SIMULATORS[@]}" -gt 1 ]]; then
    capture_dir="$OUTPUT_DIR/$slug"
    mkdir -p "$capture_dir"
  else
    capture_dir="$OUTPUT_DIR"
  fi

  xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$simulator_id" -b
  xcrun simctl install "$simulator_id" "$APP_PATH"

  tab_index=0
  for tab in "${TABS[@]}"; do
    xcrun simctl terminate "$simulator_id" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$simulator_id" "$APP_BUNDLE_ID" \
      -ui-testing \
      -skip-onboarding \
      -skip-splash \
      -ui-testing-auth-reset \
      -ui-testing-auth-skip \
      -screenshot-mode \
      -screenshot-start-tab "$tab" \
      -ui-testing-reset-data \
      -debug-polish-seed "$SEED" >/dev/null
    if [[ "$tab_index" == "0" ]]; then
      sleep "$FIRST_CAPTURE_DELAY"
    else
      sleep "$CAPTURE_DELAY"
    fi
    xcrun simctl io "$simulator_id" screenshot "$capture_dir/badvice-${tab}.png" >/dev/null
    tab_index=$((tab_index + 1))
  done
done

printf 'Screenshot-mode captures written to %s\n' "$OUTPUT_DIR"
