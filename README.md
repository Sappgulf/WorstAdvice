# Worst Advice

Worst Advice is an iOS SwiftUI app that delivers intentionally terrible guidance with escalating intensity, while keeping interaction smooth and playful.

## Highlights
- Tiered advice engine with escalation and anti-repetition logic
- Large structured corpus with category support
- Favorites and saved-advice recall
- Category filters and streak tracking
- Session and lifetime stats dashboard
- Unit test coverage for engine and app-state behavior

## Tech Stack
- Swift 5
- SwiftUI
- XCTest
- Xcode project (`WorstAdvice.xcodeproj`)

## Run
1. Open `WorstAdvice.xcodeproj` in Xcode.
2. Select the `WorstAdvice` scheme.
3. Run on an iOS Simulator (iOS 17+ target).

## Test
```bash
xcodebuild test \
  -project "WorstAdvice.xcodeproj" \
  -scheme "WorstAdvice" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## CI
- GitHub Actions workflow: `.github/workflows/ios-tests.yml`
- Runs unit tests on `push` and `pull_request` to `main`
- Uploads `.xcresult` artifacts for failures/debugging

## Collaboration
- PR template: `.github/PULL_REQUEST_TEMPLATE.md`
- Code ownership: `.github/CODEOWNERS`
- Branch protection checklist: `.github/BRANCH_PROTECTION.md`

## Project Structure
- `WorstAdvice/Engine` — core advice selection logic
- `WorstAdvice/Data` — corpus loading/indexing
- `WorstAdvice/State` — persisted app/session state
- `WorstAdvice/Views` — SwiftUI presentation layer
- `WorstAdvice/Resources` — advice corpus JSON
- `WorstAdviceTests` — engine/state tests

## Notes
- This app is comedic and fictional. Advice is intentionally bad.
