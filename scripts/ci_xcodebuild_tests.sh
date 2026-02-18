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

SIMCTL_DEVICES="$(xcrun simctl list devices available 2>/dev/null || true)"

if [ -z "$IOS_DESTINATION" ]; then
  IOS_DESTINATION="$(
    printf "%s\n" "$SIMCTL_DEVICES" \
      | awk -v wanted="$IOS_SIMULATOR_NAME" '
          /^-- iOS / {
            os = $0
            sub(/^-- iOS /, "", os)
            sub(/ --$/, "", os)
            next
          }
          $0 ~ "^[[:space:]]+" wanted " \\(" {
            line = $0
            gsub(/^[[:space:]]+/, "", line)
            name = line
            sub(/ \(.*/, "", name)
            if (os == "") os = "latest"
            print "platform=iOS Simulator,name=" name ",OS=" os
            exit
          }
        '
  )"

  if [ -z "$IOS_DESTINATION" ]; then
    IOS_DESTINATION="$(
      printf "%s\n" "$SIMCTL_DEVICES" \
        | awk '
            /^-- iOS / {
              os = $0
              sub(/^-- iOS /, "", os)
              sub(/ --$/, "", os)
              next
            }
            /^[[:space:]]+iPhone / {
              line = $0
              gsub(/^[[:space:]]+/, "", line)
              name = line
              sub(/ \(.*/, "", name)
              if (os == "") os = "latest"
              print "platform=iOS Simulator,name=" name ",OS=" os
              exit
            }
          '
    )"
  fi

  if [ -z "$IOS_DESTINATION" ]; then
    IOS_DESTINATION="platform=iOS Simulator,name=$IOS_SIMULATOR_NAME,OS=latest"
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
