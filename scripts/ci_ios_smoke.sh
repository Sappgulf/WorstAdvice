#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.build/DerivedDataSmoke}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PWD/.build/SmokeTests.xcresult}"
SMOKE_MODE="${SMOKE_MODE:-all}" # all | integration | ui
CLEAN_DERIVED_DATA="${CLEAN_DERIVED_DATA:-1}"

mkdir -p "$(dirname "$DERIVED_DATA_PATH")"
mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"

remove_path_with_retries() {
  local target="$1"
  [ -e "$target" ] || return 0
  for attempt in 1 2 3; do
    if /bin/rm -rf "$target"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if [ "$CLEAN_DERIVED_DATA" = "1" ] || [ "$CLEAN_DERIVED_DATA" = "true" ]; then
  echo "Cleaning derived data: $DERIVED_DATA_PATH"
  if ! remove_path_with_retries "$DERIVED_DATA_PATH"; then
    echo "Failed to remove derived data path: $DERIVED_DATA_PATH" >&2
    exit 1
  fi
fi

if ! remove_path_with_retries "$RESULT_BUNDLE_PATH"; then
  echo "Failed to remove existing result bundle: $RESULT_BUNDLE_PATH" >&2
  exit 1
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
