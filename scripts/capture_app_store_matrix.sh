#!/usr/bin/env bash
# Capture App Store–oriented screenshot matrix for Infernal Editorial surfaces.
# Resolves screenshot simulators, then runs capture_screenshot_mode on primary tabs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/austinbeatty/Downloads/Xcode-beta.app/Contents/Developer}"
export OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/.build/screenshots/app-store-matrix}"
export BUILD="${BUILD:-1}"
export SEED="${SEED:-424242}"
export FIRST_CAPTURE_DELAY="${FIRST_CAPTURE_DELAY:-24}"
export CAPTURE_DELAY="${CAPTURE_DELAY:-12}"

# Prefer preparing dedicated App Store screenshot devices when available.
if [[ -z "${SIMULATOR_IDS:-}" ]]; then
  if [[ -x "$ROOT_DIR/scripts/prepare_screenshot_simulators.sh" ]]; then
    SIMULATOR_IDS="$("$ROOT_DIR/scripts/prepare_screenshot_simulators.sh")"
  else
    # Fallback: first available iPhone simulator
    SIMULATOR_IDS="$(
      xcrun simctl list devices available \
        | awk -F '[()]' '/iPhone/ && /Shutdown|Booted/ {
            gsub(/[[:space:]]+$/, "", $2)
            if ($2 ~ /^[A-F0-9-]{36}$/) { print $2; exit }
          }'
    )"
  fi
fi

if [[ -z "${SIMULATOR_IDS//,/}" ]]; then
  echo "No simulators resolved. Set SIMULATOR_IDS or install an iOS runtime." >&2
  exit 1
fi

export SIMULATOR_IDS

# Primary App Store surfaces (Infernal Editorial hero frames)
TABS=(
  generate
  chaosHub
  quotes
  favorites
  history
  settings
)

# Allow override: scripts/capture_app_store_matrix.sh generate quotes
if [[ "$#" -gt 0 ]]; then
  TABS=("$@")
fi

mkdir -p "$OUTPUT_DIR"
MANIFEST="$OUTPUT_DIR/MANIFEST.md"

{
  echo "# Badvice App Store Screenshot Matrix"
  echo
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Seed: \`$SEED\`"
  echo "Simulators: \`$SIMULATOR_IDS\`"
  echo "Tabs: ${TABS[*]}"
  echo
  echo "## Editorial notes"
  echo
  echo "- Default theme should read as Infernal Editorial (espresso + copper)."
  echo "- Generate: copper CTA, stamped advice card, intensity rail."
  echo "- Missions: chaos meter thermometer."
  echo "- Quotes: daily ritual card."
  echo "- Favorites/History: archive pedestal empties or seeded keepers."
  echo "- Settings: copper gear hero + theme tiles."
  echo
  echo "## Captures"
  echo
} > "$MANIFEST"

echo "Capturing App Store matrix → $OUTPUT_DIR"
echo "Simulators: $SIMULATOR_IDS"

"$ROOT_DIR/scripts/capture_screenshot_mode.sh" "${TABS[@]}"

# Append file list to manifest
{
  echo
  echo "### Files"
  echo
  find "$OUTPUT_DIR" -name 'badvice-*.png' -type f | sort | while read -r f; do
    rel="${f#"$ROOT_DIR/"}"
    echo "- \`$rel\`"
  done
} >> "$MANIFEST"

printf 'App Store matrix written to %s\n' "$OUTPUT_DIR"
printf 'Manifest: %s\n' "$MANIFEST"
