# Badvice quality pass — October 20, 2026

## Scope and environment

Polish pass covering the complete current navigation and principal workflows: first use, guest and protected local accounts, Advice, Saved/Recent, Play, Daily, More, Party, Settings, achievements, suggestions, community activity, packs, included features, and social diagnostics. Started from `aaa5b55` with a clean working tree.

Xcode 27.0 (27A266a); iOS 27 simulator on iPhone 18 Pro and iPhone SE (3rd generation); signed iPhone 16 Pro running iOS 27.2. XCTest screenshots were inspected at ordinary and maximum accessibility text sizes. These are functional and visual checks, not a measured performance benchmark or exhaustive VoiceOver audit.

## Completed improvements

- Advice recipes preserve a complete ending rather than truncating the punchline. Compact recipes retain the situation, voice, intensity, and rewrite style. Valid “Appoint”/“Declare” imperatives pass the quality gate. Forbidden-term checks retain blocked prefixes while accepting benign words such as “difficult.” Regression tests cover these cases.
- Bracket champion export presents through the active SwiftUI sheet. Champion content scrolls at large text sizes, and a new tournament resets vote animation state.
- Saved/Recent cards display complete advice. Accessibility sizes stack metadata and dates; action icons stay within their 44-point buttons. Topic and voice filters use shorter native submenus.
- All ten offline phrase banks are truthfully presented as bundled content. Pack selection persists and reaches the actual generator. Removed the simulated download/cache service. Added direct access beside the Settings pack picker and wider pack text at accessibility sizes.
- Per the owner's decision, current features remain free. Replaced unimplemented paid offers with an Included page and real pack-browser link. This screen no longer starts StoreKit product loading.
- Protected-account security tests create a protected account instead of assuming a guest has password controls. UI scrolling derives its usable area from the real navigation and floating tab bars. Bracket export tests distinguish the share sheet Close from the underlying game Close.
- Fresh installation builds before uninstalling and reports uninstall failures instead of silently continuing.

## Verification evidence

Local `.build` logs, xcresult bundles, and exported screenshots are intentionally ignored by Git.

| Check | Result / evidence |
| --- | --- |
| Full unit suite | 194 executed, 193 passed, 1 opt-in exhaustive live-model matrix skipped, 0 failures. `PolishVerified-20261020.xcresult` / `polish-verified.log`. |
| Full simulator UI tour | 30 executed, 24 passed, 1 device-only probe skipped, 5 failures investigated. Failures concerned large-text navigation, native menu selection, Settings scroll targeting, and bracket test/presentation handling; targeted retests below establish final outcomes. |
| Compact simulator retests | Saved background persistence, maximum text/reduced motion, Saved folders/tags/filter persistence, pack persistence and generator, core navigation, and achievements/community/Included-to-packs passed across `PolishFinalUI-20261020.xcresult` and `PolishRetest-20261020.xcresult`. |
| Physical-device Apple models | 2 tests passed, 0 skipped/failures. All 16 concrete topics returned advice: 4 Apple model outputs and 12 explained local fallbacks, including 2 model guardrail refusals. A real career/wizard quote also passed. `PolishPhoneModels-20261020.xcresult`. |
| Signed phone UI and iCloud Development | 2 tests passed: core tabs/starter handoff, and temporary CloudKit profile write/read/query/delete with cleanup. `PolishPhoneUI-20261020.xcresult`. |
| Project checks | Source membership, development configuration, install-script syntax, and whitespace checks passed. |

Final focused checks also passed maximum accessibility text on the iPhone 18 Pro, all seven bracket votes through champion export/dismissal/restart, and the unavailable-service Settings diagnostic path (`PolishFinalFocused2-20261020.xcresult`). Its Saved search check encountered a transient XCTest process error; simulator termination logs show SIGTERM during the next test's launch. The isolated Saved workflow passed unchanged after restarting the QA simulator (`PolishSavedFinal2-20261020.xcresult`, 204.280 seconds). Compact rechecks exposed and corrected two test-fixture limits: retained Saved data toggled the deterministic take off, and eight short scrolls were insufficient for a full-length accessibility card.

The final compact maximum-text run passed with the simulator's actual content-size category explicitly set to `accessibility-extra-extra-extra-large`; Saved and pack screenshots were inspected (`PolishCompactMaxFinal-20261020.xcresult`, 167.216 seconds). One earlier run ignored the launch-default size, so its ordinary-text screenshots were not accepted as maximum-text proof. Across the full tour and targeted reruns, all 29 simulator UI workflows have a passing result; the device-only probe is covered separately on the signed phone. This is combined coverage across runs, not a claim that the initial full UI invocation was green.

Final signed Debug and Release device builds passed (`polish-shipping-device.log`, `polish-shipping-release.log`). The final install uses `scripts/fresh_install_ios_device.sh`; its device JSON and log are retained locally under `.build/device-install/` and `.build/polish-fresh-install.log`.

## Verification boundaries

- Two-user Game Center matches and two-user iCloud friend/feed acceptance were not verified; mocked social UI coverage is explicitly distinct from the signed Development CloudKit probe.
- CloudKit Production schema/roles were not modified or validated. These results do not establish App Store release readiness.
- Minimum deployment target iOS 18.6 and iPad layouts were not runtime-tested in this pass.
- Purchase flows are outside this free build's UI. Future monetization needs real entitlement enforcement and sandbox transaction coverage before offers return.
- No measured before/after performance claim is made. The exhaustive opt-in live-model matrix remains skipped; real phone model tests cover the narrower matrix described above.
