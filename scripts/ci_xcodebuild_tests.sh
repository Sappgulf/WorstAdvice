#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator}"
SIMULATOR_UDID="${SIMULATOR_UDID:-}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.build/DerivedData}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$PWD/.build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult}"
SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-$PWD/.build/SourcePackages}"

mkdir -p "$(dirname "$DERIVED_DATA_PATH")"
mkdir -p "$(dirname "$RESULT_BUNDLE_PATH")"
mkdir -p "$SOURCE_PACKAGES_PATH"

node scripts/check_project_sources.js
python3 scripts/check_dev_configuration.py

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

if [[ -n "$SIMULATOR_UDID" ]]; then
  IOS_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
elif [[ "$IOS_DESTINATION" == "platform=iOS Simulator" ]]; then
  RESOLVED_SIMULATOR_UDID="$(
    xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null \
      | awk '
        /platform:iOS Simulator/ && /id:/ && $0 !~ /dvtdevice-DVTiOSDeviceSimulatorPlaceholder/ {
          print
          exit
        }
      ' \
      | sed -E 's/.*id:([^,}]+).*/\1/'
  )"

  if [[ -n "$RESOLVED_SIMULATOR_UDID" ]]; then
    IOS_DESTINATION="platform=iOS Simulator,id=$RESOLVED_SIMULATOR_UDID"
  fi
fi

echo "Using destination: $IOS_DESTINATION"

CLEANUP_SIMULATOR_UDID="${SIMULATOR_UDID:-${RESOLVED_SIMULATOR_UDID:-}}"
if [[ -z "$CLEANUP_SIMULATOR_UDID" && "$IOS_DESTINATION" =~ id=([[:xdigit:]-]+) ]]; then
  CLEANUP_SIMULATOR_UDID="${BASH_REMATCH[1]}"
fi
if [[ -n "$CLEANUP_SIMULATOR_UDID" ]]; then
  echo "Cleaning stale simulator app/test-runner state for: $CLEANUP_SIMULATOR_UDID"
  xcrun simctl terminate "$CLEANUP_SIMULATOR_UDID" com.worstadvice.app >/dev/null 2>&1 || true
  xcrun simctl terminate "$CLEANUP_SIMULATOR_UDID" com.worstadvice.uitests.xctrunner >/dev/null 2>&1 || true
  xcrun simctl terminate "$CLEANUP_SIMULATOR_UDID" com.worstadvice.uitests >/dev/null 2>&1 || true
fi

xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH"

if [[ -e "$RESULT_BUNDLE_PATH" ]]; then
  echo "Result bundle already exists. Choose a fresh RESULT_BUNDLE_PATH: $RESULT_BUNDLE_PATH" >&2
  exit 1
fi

xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  ONLY_ACTIVE_ARCH=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO
