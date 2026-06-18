# Browser Screenshot QA

Use this checklist for browser-visible simulator proof and App Store screenshot prep.

## Required Screens

- Generate: command card, selected lane/tone, situation field, primary action, and a generated advice card.
- Missions: Mission Command, Progression Path, Daily Mission, Weekly Mission, and Season Status.
- Quotes: Daily pick, Daily Ritual, Quote Spotlight, and visible quote rows.
- Friends: Friends Command, Setup Path, section picker, and either setup or first-friend state.
- Library: Saved and History with at least one card when seeded data is available.
- Settings: theme picker, share settings, upgrade entry, and diagnostics surfaces.

## Browser Proof

1. Build and install Badvice on the selected iOS Simulator.
2. Launch with screenshot-mode UI-test arguments for deterministic startup:
   `-ui-testing -skip-onboarding -skip-splash -ui-testing-auth-reset -ui-testing-auth-skip -screenshot-mode -debug-polish-seed 424242`.
   Add `-screenshot-start-tab generate`, `chaosHub`, `friends`, `quotes`, `favorites`, `history`, or `settings` for the first frame you want.
3. Start `serve-sim` pinned to the same Simulator UDID.
4. Open the printed local URL in the Codex in-app browser.
5. Confirm the browser shows the real running app frame, not just the helper page.
6. Capture proof screenshots under `.build/browser-proof/`.

## Scripted Export

Use the screenshot-mode exporter when you need repeatable tab captures without the browser mirror:

```bash
scripts/capture_screenshot_mode.sh
```

By default it builds with the beta Xcode toolchain, installs on the `iPhone 17 Pro` simulator, and writes:

- `.build/screenshots/screenshot-mode/badvice-generate.png`
- `.build/screenshots/screenshot-mode/badvice-chaosHub.png`
- `.build/screenshots/screenshot-mode/badvice-friends.png`
- `.build/screenshots/screenshot-mode/badvice-quotes.png`
- `.build/screenshots/screenshot-mode/badvice-favorites.png`
- `.build/screenshots/screenshot-mode/badvice-history.png`
- `.build/screenshots/screenshot-mode/badvice-settings.png`

Pass tab raw values to capture a smaller set, for example:

```bash
BUILD=0 scripts/capture_screenshot_mode.sh generate chaosHub quotes
```

The exporter waits 24 seconds for the first tab on each simulator and 12 seconds for later tabs so fresh simulator launches, screenshot-mode fixtures, and tab routing can settle. Override with `FIRST_CAPTURE_DELAY` and `CAPTURE_DELAY=6` only after checking the requested tab is captured reliably.

For multi-device capture, pass comma-separated Simulator UDIDs. With more than one simulator, each device writes into a slugged subfolder:

```bash
SIMULATOR_IDS="47F86C58-BDC0-472D-9A4F-3AC719B015FB,OTHER-UDID" scripts/capture_screenshot_mode.sh
```

Create or resolve the default App Store screenshot simulator set, then feed it directly into the exporter:

```bash
SIMULATOR_IDS="$(scripts/prepare_screenshot_simulators.sh)" \
  OUTPUT_DIR=.build/screenshots/app-store-matrix \
  scripts/capture_screenshot_mode.sh generate chaosHub friends quotes settings
```

Example output:

- `.build/screenshots/screenshot-mode/iphone-17-pro/badvice-generate.png`
- `.build/screenshots/screenshot-mode/iphone-17-pro/badvice-chaosHub.png`

## App Store Notes

- Capture current primary surfaces after the smoke suite passes.
- Prefer real app UI over mocked marketing comps.
- Use screenshot mode for proof captures; it preloads deterministic polish fixtures, reduces motion, skips onboarding/splash, and can open a selected tab.
- Keep screenshots readable at phone scale: no tiny debug-only text, no overlapping controls, and no stale old tab labels.
