# Badvice App Store launch checklist

Current release verified November 18, 2026 at approximately 1:30 PM CST (America/Chicago): **Ready for Distribution**, version 6.4 (2026111704). At the owner's direction, immediate release was confirmed for all 172 supported regions, superseding the November 21 pre-order date. Regions show **Processing to Available**. The public US listing still returned HTTP 404 during propagation; public downloads remain independently unverified. Historical March archives and June checklist results do not establish current release readiness.

## Release identity

- App: Badvice, `com.worstadvice.app`.
- Widget: `com.worstadvice.app.widget`.
- Current source version/build: 6.4 (2026111704), aligned across app and widget, including the widget's resolved Info.plist values.
- Minimum deployment: iOS 18.6. Swift language mode: Swift 5.
- Signing team: FW6FWBCF5U.
- Icon: all 18 catalog files validated for exact dimensions and no alpha; marketing image is 1024 × 1024.

## Current evidence

See [submission preparation](app-store-submission-2026-11-17.md) for listing copy, reviewer notes, and verification results. Build/test artifacts are in ignored `.build/`.

## Verification and submission

- [x] Unit/integration tests and primary UI workflows pass; final focused tests cover the last edits.
- [x] Inspect current UI captures, including privacy and generation.
- [x] Signed Release archive succeeds with current sources.
- [x] Upload completes and build 2026111704 finishes processing in App Store Connect.
- [x] Select and save build 2026111704 in App Store version 6.4.
- [x] Validate/import the additive CloudKit schema and deploy it to Production.
- [ ] Verify production participant operations with two signed iCloud accounts; see [CloudKit setup](cloudkit_schema_setup.md).
- [ ] Verify two-user Game Center invitations, turns, reconnect, and completion on signed devices.
- [x] Publish/select a public Badvice privacy-policy URL and align App Privacy answers with actual collection.
- [x] Inspect and upload four native screenshots each for required medium-display iPhone and 13-inch iPad.
- [x] Save subtitle, description, keywords, support URL, age rating, export compliance, free pricing, and availability.
- [x] Obtain the owner's content-rights confirmation.
- [x] Save the confirmed affirmative content-rights declaration in App Store Connect after renewing sign-in.
- [x] Submit and confirm Waiting for Review in both the version and submission details pages.
- [x] Configure November 21 pre-order release for 172 supported regions and verify it persists after resubmission.
- [x] Publish and inspect the public marketing, support, and privacy site; update all corresponding App Store URLs.
- [x] After Apple approval, use Release This Version; verify Ready for Distribution for build 2026111704.
- [x] Release to customers immediately in all 172 existing pre-order regions; verify Processing to Available and removal of the November 21 schedule.
- [ ] Independently verify the public App Store listing and downloads after storefront propagation.

[Confirmed submission](https://appstoreconnect.apple.com/apps/6759284684/distribution/reviewsubmissions/details/40c9da18-7f9d-48fe-b0d3-0a537f877817). [App Store listing](https://apps.apple.com/app/id6759284684). [Public landing page](https://badvice-app.sappgulf.chatgpt.site). Approval and immediate release are complete; storefront propagation is in progress. The unchecked signed two-user checks above remain verification gaps; release does not establish their outcomes.
