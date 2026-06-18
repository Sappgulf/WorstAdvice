#!/usr/bin/env bash
set -euo pipefail

RUNTIME="${RUNTIME:-}"
if [[ -z "$RUNTIME" ]]; then
  RUNTIME="$(
    xcrun simctl list runtimes available \
      | awk '/com\.apple\.CoreSimulator\.SimRuntime\.iOS/ {print $NF}' \
      | tail -1
  )"
fi

if [[ -z "$RUNTIME" ]]; then
  echo "No available iOS Simulator runtime found." >&2
  exit 1
fi

DEVICE_MATRIX="${DEVICE_MATRIX:-Badvice Screenshot iPhone 17 Pro=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro;Badvice Screenshot iPhone 17 Pro Max=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max;Badvice Screenshot iPhone SE=com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation}"

ids=()
IFS=';' read -r -a entries <<< "$DEVICE_MATRIX"
for entry in "${entries[@]}"; do
  [[ -n "$entry" ]] || continue
  name="${entry%%=*}"
  device_type="${entry#*=}"

  if [[ -z "$name" || -z "$device_type" || "$name" == "$device_type" ]]; then
    echo "Invalid DEVICE_MATRIX entry: $entry" >&2
    exit 1
  fi

  existing_id="$(
    xcrun simctl list devices available \
      | awk -v name="$name" '
        index($0, name " (") {
          match($0, /\([A-F0-9-]+\)/)
          if (RSTART > 0) {
            print substr($0, RSTART + 1, RLENGTH - 2)
            exit
          }
        }
      '
  )"

  if [[ -n "$existing_id" ]]; then
    ids+=("$existing_id")
    continue
  fi

  ids+=("$(xcrun simctl create "$name" "$device_type" "$RUNTIME")")
done

(
  IFS=,
  printf '%s\n' "${ids[*]}"
)
