# Badvice

A native SwiftUI satire app for confidently wrong advice. The default design is **Mischief magazine**: warm paper, editorial type, red ink, and playful stamps.

## The experience

- **Advice:** choose a topic and voice, optionally describe your situation, and generate a take. Save, copy, export an image, rewrite it, or reveal a sensible reality check.
- **Saved:** search and organize saved advice, or browse recent history. History is capped at 50 entries.
- **Play:** daily and weekly missions, streaks, and an advice bracket.
- **Daily:** the daily quote, a searchable quote archive, and starter prompts.
- **Party:** local pass-the-phone play plus 2–8 player Game Center matches. Online players take turns generating advice and voting; Game Center keeps the match available between turns.
- **Settings:** themes, ten bundled offline content packs with a persistent selection, accessibility preferences, sharing, Apple Intelligence, local account security, suggestions, and social diagnostics. All current features are included without paid unlocks or subscriptions.

Guest mode has a stable, separate local history. Protected accounts keep their existing password workflow. Local Badvice accounts are not Apple IDs and do not provide cross-device account sync.

Advice and Party use Apple’s on-device Foundation Models on iOS 26+ when Apple Intelligence is enabled and ready. Both cover every concrete topic and voice through the same structured request contract. Advice also supports intensity and rewrites, and ranks successful Apple outputs with its other candidates. Party generates one take per player. Both surfaces identify the actual provider and fall back to the offline Bureau Engine when Apple Intelligence is unavailable or generation fails; Party rounds retain that source and explain local fallbacks. Legacy settings migrate once to Apple; later explicit engine choices persist. The widget’s daily quotes use local content. Advice is entertainment, not guidance.

Online Party uses Game Center turn-based matches rather than the CloudKit public social database. Invited players choose their own provider; each take, vote, and final verdict is stored in the Game Center match. Local pass-the-phone play remains available without Game Center sign-in.

## Architecture

- SwiftUI + Observation for presentation and state.
- SwiftData for local advice, votes, suggestions, settings, and progression, scoped by account.
- Keychain for protected-account credentials; guest state stays separate in local preferences.
- CloudKit CKRecords for optional social data in `iCloud.com.worstadvice.app`.
- WidgetKit for daily quotes and streak activities.
- Minimum deployment target: iOS 18.6. Swift language mode: Swift 5.

Local SwiftData deliberately uses `cloudKitDatabase: .none`: its unique constraints and required fields are incompatible with automatic CloudKit persistence. Social data has a separate backend. Local history does not sync across devices.

## Build and test

Open `Badvice.xcodeproj`, select the `Badvice` scheme, and choose an installed simulator. Command-line workflows use the selected Xcode (`xcode-select -p`), without a machine-specific beta path.

```bash
node scripts/check_project_sources.js
python3 scripts/check_dev_configuration.py
xcrun simctl list devices available
```

Choose an explicit simulator UDID:

```bash
SIMULATOR_UDID="YOUR_SIMULATOR_UDID" bash scripts/ci_xcodebuild_tests.sh
```

For a shorter integration/UI smoke pass:

```bash
DESTINATION="platform=iOS Simulator,id=YOUR_SIMULATOR_UDID" bash scripts/ci_ios_smoke.sh
```

Scripts share incremental build caches, build the active simulator architecture, run tests serially, and preserve old result bundles. Set `RESULT_BUNDLE_PATH` to a new path for each run. Unsigned simulator tests do not validate signed iCloud entitlements or production services.

## Simulator fixtures

UI tests use `-ui-testing -skip-onboarding -skip-splash`. Add `-ui-testing-auth-skip` for a guest test session, or exercise `auth.guest` for guest entry. Protected-account tests create an account through signup. `-ui-testing-reset-data` resets the current test account's data. `-ui-testing-social-mock` uses the explicit mock backend; `-ui-testing-force-social-unavailable` exercises the unavailable state.

For deterministic visual captures:

```bash
SIMULATOR_ID="YOUR_SIMULATOR_UDID" bash scripts/capture_screenshot_mode.sh
```

The UI suites save named screenshots in their xcresult attachments. They test current controls, persistence, validation, exports, large text, onboarding, account workflows, and social diagnostics. Retired demo invite-code behavior is replaced by actual party-game tests.

## iCloud

Read [CloudKit setup](docs/cloudkit_schema_setup.md) before testing social features. The optional backend uses the **public database**. A client-side friends filter does not enforce private sharing. Do not post sensitive content.

The local fixes cover optional-record fetches, transient profile failures, iCloud identity validation and change notifications, account-scoped retry queues, and stable share IDs. The app registers the `badvice://` URL scheme used by widget links. Unsigned builds report CloudKit as unavailable without constructing a container or manufacturing profiles. Signed builds use the live backend. Server schema deployment, security roles, and cross-user writes still need signed development and two-user verification. Do not enable broad public write access to make those operations pass.

## Game Center

The app target includes the Game Center capability and entitlement. The App ID and device provisioning profile must also allow Game Center before signed-device invites work. Test invitations, reconnects, turn delivery, and match completion with two signed Game Center accounts on separate devices; simulator builds validate the code and local turn-state rules, not Apple’s live multiplayer service.

## Repository

The canonical app source is `Badvice/`, widgets are in `WorstAdviceWidget/`, unit tests in `WorstAdviceTests/`, and UI tests in `BadviceUITests/`. Keep build artifacts in ignored `.build/`. Do not reintroduce nested repository copies.
