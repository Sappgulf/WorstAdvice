#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME_NAME="${SCHEME_NAME:-WorstAdvice}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 15,OS=latest}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.derivedData}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$ROOT_DIR/TestResults.xcresult}"
XCODEBUILD_LOG_PATH="${XCODEBUILD_LOG_PATH:-$ROOT_DIR/xcodebuild-test.log}"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "Project not found: $PROJECT_PATH"
  exit 64
fi

rm -rf "$DERIVED_DATA_PATH" "$RESULT_BUNDLE_PATH"

echo "Using project: $PROJECT_PATH"
echo "Using scheme: $SCHEME_NAME"
echo "Using destination: $IOS_DESTINATION"

SCHEMES_OUTPUT="$(xcodebuild -list -project "$PROJECT_PATH" | tr -d '\r')"
if ! printf '%s\n' "$SCHEMES_OUTPUT" | awk -v scheme="$SCHEME_NAME" '
  /^\s*Schemes:\s*$/ {in_schemes=1; next}
  in_schemes && NF==0 {exit}
  in_schemes {gsub(/^\s+|\s+$/, "", $0); if ($0==scheme) found=1}
  END {exit(found ? 0 : 1)}
'; then
  echo "Shared/visible scheme '$SCHEME_NAME' not found in project '$PROJECT_PATH'."
  echo "$SCHEMES_OUTPUT"
  exit 65
fi

xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME"

set -o pipefail
xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  | tee "$XCODEBUILD_LOG_PATH"
