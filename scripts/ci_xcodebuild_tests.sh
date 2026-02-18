#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
IOS_SIMULATOR_NAME="${IOS_SIMULATOR_NAME:-iPhone 17}"
IOS_DESTINATION="${IOS_DESTINATION:-}"
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

AVAILABLE_DESTINATIONS="$(xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme "$SCHEME" 2>/dev/null || true)"

if [ -z "$IOS_DESTINATION" ]; then
  if printf "%s\n" "$AVAILABLE_DESTINATIONS" | grep -Fq "platform:iOS Simulator" \
    && printf "%s\n" "$AVAILABLE_DESTINATIONS" | grep -Fq "name:$IOS_SIMULATOR_NAME"; then
    IOS_DESTINATION="platform=iOS Simulator,name=$IOS_SIMULATOR_NAME,OS=latest"
  else
    FALLBACK_LINE="$(
      printf "%s\n" "$AVAILABLE_DESTINATIONS" \
        | awk '/platform:iOS Simulator/ && /name:iPhone / { print; exit }'
    )"

    if [ -z "$FALLBACK_LINE" ]; then
      echo "No available iOS simulator destination found." >&2
      printf "%s\n" "$AVAILABLE_DESTINATIONS" >&2
      exit 1
    fi

    FALLBACK_NAME="$(
      printf "%s\n" "$FALLBACK_LINE" | sed -E 's/.*name:([^,}]+).*/\1/' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
    )"
    FALLBACK_OS="$(
      printf "%s\n" "$FALLBACK_LINE" | sed -E 's/.*OS:([^,}]+).*/\1/' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
    )"

    IOS_DESTINATION="platform=iOS Simulator,name=$FALLBACK_NAME,OS=$FALLBACK_OS"
  fi
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
  CODE_SIGNING_ALLOWED=NO
