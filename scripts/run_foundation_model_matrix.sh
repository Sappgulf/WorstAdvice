#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DESTINATION="${DESTINATION:-}"
if [[ -z "$DESTINATION" ]]; then
  echo "Set DESTINATION to an eligible iPhone or simulator, for example platform=iOS,id=<UDID>." >&2
  exit 2
fi

RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$ROOT_DIR/.build/FoundationModelMatrix-$(date +%Y%m%d-%H%M%S).xcresult}"
LOG_PATH="${LOG_PATH:-$ROOT_DIR/.build/FoundationModelMatrix-$(date +%Y%m%d-%H%M%S).log}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/DerivedData}"

mkdir -p "$ROOT_DIR/.build"
if [[ -e "$RESULT_BUNDLE_PATH" ]]; then
  echo "Result bundle already exists. Choose a fresh RESULT_BUNDLE_PATH: $RESULT_BUNDLE_PATH" >&2
  exit 1
fi

node scripts/check_project_sources.js
python3 scripts/check_dev_configuration.py

set +e
BADVICE_LIVE_MODEL_MATRIX=1 xcodebuild test \
  -project Badvice.xcodeproj \
  -scheme Badvice \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -only-testing:BadviceTests/AppSessionSmokeTests/testLiveAppleFoundationModelCategoryToneMatrixWhenEnabled \
  -parallel-testing-enabled NO \
  ONLY_ACTIVE_ARCH=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  2>&1 | tee "$LOG_PATH"
XCODEBUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ "$XCODEBUILD_STATUS" -ne 0 ]]; then
  exit "$XCODEBUILD_STATUS"
fi

if ! rg -q "LIVE MATRIX OPT-IN ENABLED|LIVE MATRIX: Apple model unavailable" "$LOG_PATH"; then
  echo "The live matrix did not start; inspect the test runner environment and log: $LOG_PATH" >&2
  exit 1
fi

echo "Live Foundation Models matrix result bundle: $RESULT_BUNDLE_PATH"
