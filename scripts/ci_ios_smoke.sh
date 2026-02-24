#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.build/DerivedDataSmoke}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PWD/.build/SmokeTests.xcresult}"
SMOKE_MODE="${SMOKE_MODE:-all}" # all | integration | ui

mkdir -p "$(dirname "$DERIVED_DATA_PATH")"
mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
if [ -e "$RESULT_BUNDLE_PATH" ]; then
  for attempt in 1 2 3; do
    if /bin/rm -rf "$RESULT_BUNDLE_PATH"; then
      break
    fi
    sleep 1
  done
  if [ -e "$RESULT_BUNDLE_PATH" ]; then
    echo "Failed to remove existing result bundle: $RESULT_BUNDLE_PATH" >&2
    exit 1
  fi
fi

echo "Running iOS smoke tests on: $DESTINATION"

ONLY_TESTING_ARGS=()
case "$SMOKE_MODE" in
  all)
    ONLY_TESTING_ARGS+=("-only-testing:BadviceTests/AppSessionSmokeTests")
    ONLY_TESTING_ARGS+=("-only-testing:BadviceUITests/BadviceUITests")
    ;;
  integration)
    ONLY_TESTING_ARGS+=("-only-testing:BadviceTests/AppSessionSmokeTests")
    ;;
  ui)
    ONLY_TESTING_ARGS+=("-only-testing:BadviceUITests/BadviceUITests")
    ;;
  *)
    echo "Unsupported SMOKE_MODE: $SMOKE_MODE (expected all|integration|ui)" >&2
    exit 2
    ;;
esac

xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  "${ONLY_TESTING_ARGS[@]}" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  CODE_SIGNING_ALLOWED=NO
