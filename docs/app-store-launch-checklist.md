# Badvice App Store Launch Checklist

Last verified: 2026-03-07 22:53 CST (America/Chicago)

## 1) Release Build Validation

Status: COMPLETE

- `xcodebuild -project Badvice.xcodeproj -scheme Badvice -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- Latest log: `.build/release-build-final.log`
- Result: `** BUILD SUCCEEDED **`

## 2) Archive / Export Sanity

Status: COMPLETE

- Unsigned archive: `.build/Badvice-AppStore-20260307-224343.xcarchive` (succeeded)
- Signed archive: `.build/Badvice-AppStore-SIGNED-final-20260307-225114.xcarchive` (succeeded)
- App Store Connect export: `.build/AppStoreSignedExport-final-20260307-225114` (succeeded)
- Latest signed export log: `.build/export-signed-final.log`
- Export command used `method = app-store-connect` with automatic signing and team `FW6FWBCF5U`

## 3) App Store Metadata / Packaging Sweep

Status: COMPLETE (codebase) + MANUAL ITEMS REMAIN

### Verified in project

- App bundle ID: `com.worstadvice.app`
- Widget bundle ID: `com.worstadvice.app.widget`
- App version/build: `4.4 (2026022501)`
- Widget version/build: `4.4 (2026022501)`
- Deployment target: iOS `18.6`
- Display name: `Badvice`
- Category: `public.app-category.entertainment`
- App icon set includes `ios-marketing` 1024x1024 asset (`AppIcon-AppStore-1024.png`)
- Entitlements include CloudKit (`iCloud.com.worstadvice.app`)

### Manual App Store Connect tasks (required before submission)

- Confirm App Privacy questionnaire answers are fully up to date.
- Complete/update app metadata (subtitle, description, keywords, support/marketing URLs).
- Upload/select final screenshots for all required device classes.
- Set pricing/availability and release strategy.
- Confirm export compliance / content rights / age rating answers.

### Notes

- Privacy manifest file (`PrivacyInfo.xcprivacy`) is not currently present in this repo.
  Validate whether your used APIs/SDKs require one before submission.
- Xcode emits a non-blocking asset notice about legacy iPad `76x76@1x` app icon support.
