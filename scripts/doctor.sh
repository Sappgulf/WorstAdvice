#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Badvice.xcodeproj}"
SCHEME="${SCHEME:-Badvice}"
IOS_SIMULATOR_NAME="${IOS_SIMULATOR_NAME:-iPhone 17}"

echo "Badvice doctor"
echo "============="
echo "Repo root: $(git rev-parse --show-toplevel)"
echo "Project:   $PROJECT_PATH"
echo "Scheme:    $SCHEME"
echo

echo "[1/4] Source check"
node scripts/check_project_sources.js
echo

echo "[2/4] Scheme check"
xcodebuild -list -project "$PROJECT_PATH" | awk -v scheme="$SCHEME" '
  /^[[:space:]]*Schemes:[[:space:]]*$/ { in_schemes = 1; next }
  in_schemes && NF == 0 { exit }
  in_schemes {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
    if ($0 == scheme) found = 1
  }
  END { exit(found ? 0 : 1) }
' || {
  echo "Missing scheme '$SCHEME' in '$PROJECT_PATH'." >&2
  exit 1
}
echo "Scheme '$SCHEME' is present."
echo

echo "[3/4] Simulator check"
SIMULATORS="$(xcrun simctl list devices available 2>/dev/null || true)"
if [ -z "$SIMULATORS" ]; then
  echo "No available simulators reported by simctl." >&2
  exit 1
fi

PREFERRED_MATCH="$(
  printf "%s\n" "$SIMULATORS" | awk -v wanted="$IOS_SIMULATOR_NAME" '
    $0 ~ "^[[:space:]]+" wanted " \\(" {
      line = $0
      gsub(/^[[:space:]]+/, "", line)
      print line
      exit
    }
  '
)"
if [ -n "$PREFERRED_MATCH" ]; then
  echo "Preferred simulator: $PREFERRED_MATCH"
else
  echo "Preferred simulator '$IOS_SIMULATOR_NAME' not found."
fi

echo "Available iPhone simulators:"
printf "%s\n" "$SIMULATORS" | awk '
  /^[[:space:]]+iPhone / {
    line = $0
    gsub(/^[[:space:]]+/, "", line)
    print "  " line
    count++
    if (count == 8) exit
  }
'
echo

echo "[4/4] Feature flag overrides"
echo "  Explore tab:"
echo "    launch args: -enable-explore-tab / -disable-explore-tab"
echo "    env var:     BADVICE_FEATURE_EXPLORE_TAB"
echo "  Group challenges tab:"
echo "    launch args: -enable-group-challenges-tab / -disable-group-challenges-tab"
echo "    env var:     BADVICE_FEATURE_GROUP_CHALLENGES_TAB"
