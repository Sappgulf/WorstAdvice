# Simulator Screenshot QA

Capture the running SwiftUI app after the functional tests pass. Use the selected Xcode (`xcode-select -p`) and an explicit simulator UDID from `xcrun simctl list devices available`.

## Current product tour

- **Advice:** topic, voice, optional situation, generation, intensity, rewrites, reality check, save, copy, and system export.
- **Saved:** saved advice, recent history, search, category/voice filters, folders, and tags.
- **Play:** daily/weekly missions, progress, and the advice bracket through champion, sharing, and restart.
- **Daily:** today's quote, likes, remix, starter prompts, and archive.
- **More:** starter ideas, Party, recent history, and Settings.
- **Party:** provider choice, player validation, pass-the-phone voting, restored rounds, verdict, and export. Online matches need two signed Game Center accounts.
- **Settings:** engine, pack, theme, accessibility, and local account controls. Advanced settings include achievements, suggestions, community activity, offline packs, included features, Apple model status, and social diagnostics.
- **First use:** splash, guest entry, optional protected-account signup, and onboarding.

Inspect normal and maximum accessibility text. Check sheet dismissal, keyboard dismissal, the floating tab bar, long advice, empty results, unavailable services, and persisted selections. A successful build alone does not validate these interactions.

## Repeatable tab captures

```bash
SIMULATOR_ID="YOUR_SIMULATOR_UDID" scripts/capture_screenshot_mode.sh
```

The script builds and installs the app, then launches each tab with deterministic UI-test fixtures. It writes PNGs into `.build/screenshots/screenshot-mode/`. The default set is `generate`, `chaosHub`, `quotes`, `favorites`, `history`, `settings`, `explore`, and `groupChallenges`.

To reuse the existing build or capture selected tabs:

```bash
BUILD=0 SIMULATOR_ID="YOUR_SIMULATOR_UDID" \
  scripts/capture_screenshot_mode.sh generate chaosHub quotes
```

Set `SIMULATOR_IDS` to comma-separated UDIDs for multiple devices. Each device gets its own subfolder. Keep the default settling delays unless you have confirmed the requested screen is captured reliably.

## Maximum text size

For a repeatable device-level check, set the QA simulator's preferred size explicitly rather than relying only on app launch defaults:

```bash
xcrun simctl ui YOUR_SIMULATOR_UDID content_size accessibility-extra-extra-extra-large
xcrun simctl ui YOUR_SIMULATOR_UDID content_size
```

Run the accessibility workflow, inspect its screenshot pixels, then restore with `content_size large`. A passed test name alone does not establish the applied text size.

## Live browser mirror

Use the iOS Simulator Browser skill to start `serve-sim` pinned to the same UDID. Open its printed localhost URL in the Codex browser and confirm a real app frame appears. Stop only that simulator's helper when done. Do not interact with a simulator while XCTest is controlling it, or reuse a simulator owned by another active task.

## Evidence and store assets

The UI tests retain named screenshots in the xcresult attachments. Export them with:

```bash
xcrun xcresulttool export attachments \
  --path .build/YOUR_RESULT.xcresult \
  --output-path .build/qa-attachments
```

Review the actual pixels for overlapping controls, clipped text, unreadable colors, and content hidden by the tab bar. Debug fixtures are QA evidence; review them separately before using them as App Store assets. Refresh widget screenshots when marketing widget features. Simulator captures do not establish signed CloudKit, Game Center, StoreKit purchase, or physical-device behavior.
