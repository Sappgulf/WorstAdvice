#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.build/DerivedData}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PWD/.build/TestResults.xcresult}"
SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-$PWD/.build/SourcePackages}"

mkdir -p "$(dirname "$DERIVED_DATA_PATH")"
mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
mkdir -p "$SOURCE_PACKAGES_PATH"

node scripts/check_project_sources.js

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

if ! xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
  | grep -q "platform:iOS Simulator"; then
  echo "No eligible iOS Simulator destinations are installed for Xcode." >&2
  echo "Install a simulator runtime in Xcode > Settings > Components or set IOS_DESTINATION manually." >&2
  exit 1
fi

echo "Using destination: $IOS_DESTINATION"

xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH"

rm -rf "$RESULT_BUNDLE_PATH"

xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
