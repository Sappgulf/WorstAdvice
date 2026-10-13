#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
DESTINATION="${DESTINATION:-platform=iOS Simulator}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.build/DerivedData}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PWD/.build/SmokeTests-$(date +%Y%m%d-%H%M%S).xcresult}"
SMOKE_MODE="${SMOKE_MODE:-all}" # all | integration | ui

mkdir -p "$(dirname "$DERIVED_DATA_PATH")"
mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
if [ -e "$RESULT_BUNDLE_PATH" ]; then
  echo "Result bundle already exists. Choose a fresh RESULT_BUNDLE_PATH: $RESULT_BUNDLE_PATH" >&2
  exit 1
fi

node scripts/check_project_sources.js
python3 scripts/check_dev_configuration.py

if ! xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
  | grep -q "platform:iOS Simulator"; then
  echo "No eligible iOS Simulator destinations are installed for Xcode." >&2
  echo "Install a simulator runtime in Xcode > Settings > Components or set DESTINATION manually." >&2
  exit 1
fi

if [[ "$DESTINATION" == "platform=iOS Simulator" ]]; then
  SMOKE_SIM_ID="$(xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null | awk '/platform:iOS Simulator/ && /id:/ && !/Placeholder/ {print; exit}' | sed -E 's/.*id:([^,}]+).*/\1/')"
  [[ -n "$SMOKE_SIM_ID" ]] || { echo "No simulator destination resolved." >&2; exit 1; }
  DESTINATION="platform=iOS Simulator,id=$SMOKE_SIM_ID"
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
  -parallel-testing-enabled NO \
  ONLY_ACTIVE_ARCH=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO
