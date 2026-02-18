#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
IOS_SIMULATOR_NAME="${IOS_SIMULATOR_NAME:-iPhone 15}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.build/DerivedData}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PWD/.build/TestResults.xcresult}"
SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-$PWD/.build/SourcePackages}"

mkdir -p "$(dirname "$DERIVED_DATA_PATH")"
mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
mkdir -p "$SOURCE_PACKAGES_PATH"

if ! xcodebuild -list -project "$PROJECT_PATH" | awk -v scheme="$SCHEME" '
  /^[[:space:]]*Schemes:[[:space:]]*$/ { in_schemes = 1; next }
  in_schemes && NF == 0 { exit }
  in_schemes {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
    if ($0 == scheme) found = 1
  }
  END { exit(found ? 0 : 1) }
'; then
  echo "Scheme '$SCHEME' not found in project '$PROJECT_PATH'." >&2
  xcodebuild -list -project "$PROJECT_PATH" >&2 || true
  exit 1
fi

SIMULATOR_ID="$(
  xcrun simctl list devices available \
    | awk -v device="$IOS_SIMULATOR_NAME" '$0 ~ "^[[:space:]]+" device " \\(" { print; exit }' \
    | grep -Eo '[0-9A-F-]{36}' \
    | head -n 1 \
    || true
)"

if [ -z "$SIMULATOR_ID" ]; then
  SIMULATOR_ID="$(
    xcrun simctl list devices available \
      | awk '/^[[:space:]]+iPhone / { print; exit }' \
      | grep -Eo '[0-9A-F-]{36}' \
      | head -n 1 \
      || true
  )"
fi

if [ -z "$SIMULATOR_ID" ]; then
  echo "No available iOS simulator found." >&2
  xcrun simctl list devices available >&2 || true
  exit 1
fi

echo "Using destination: platform=iOS Simulator,id=$SIMULATOR_ID"

xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH"

rm -rf "$RESULT_BUNDLE_PATH"

xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  CODE_SIGNING_ALLOWED=NO
