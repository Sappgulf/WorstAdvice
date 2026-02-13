# The Worst Advice (iOS)

A SwiftUI satire app that generates confidently wrong advice that still sounds plausible.

## Version
- `1.0.0`

## Features
- Four-tab app: `Generate`, `Favorites`, `History`, `Settings`
- Categories (10): Dating, Fitness, Career, Money, Parenting, Tech, Social, Cooking, Travel, Productivity
- Tone modes (8): Corporate Consultant, Alpha Podcast, Wizard, Influencer, Toxic Best Friend, Boomer, Crypto Bro, Minimalist Monk
- Rule-based advice engine:
  - Category rules define bad principles, keywords, forbidden patterns, and templates
  - Tone profiles define phrasing/rhetorical style
  - Output includes advice line plus optional fake rationale line
  - Optional user situation prompt is woven into output when safe
- Safety layer blocks hateful, self-harm, and wrongdoing-oriented outputs
- SwiftData persistence:
  - Favorites storage
  - History capped to last 50 generated items
  - Persisted settings
- Share-first workflow:
  - One-tap copy/share
  - `Surprise Me` and deterministic `Daily Drop` quick generation actions
  - Image card export with 3 templates, subtle noise, rounded card, watermark
  - Supports square and story aspect ratios
  - Optional footer disclaimer: `For entertainment only`
- Discovery workflows:
  - Favorites supports list/grid plus search and category filters
  - History supports search and category filters
- Accessibility/perf:
  - Dynamic Type-friendly layout
  - VoiceOver labels for key controls
  - Large tap targets and high-contrast theme tokens
  - Instant local generation and rendering

## Architecture
- UI: SwiftUI
- Pattern: MVVM
- Persistence: SwiftData (`AdviceRecord`, `AppSettingsEntity`)
- Core modules:
  - `WorstAdvice/Models/AdviceModels.swift`: enums + shared models
  - `WorstAdvice/Data/AdviceStore.swift`: category/tone rule definitions
  - `WorstAdvice/Engine/AdviceEngine.swift`: deterministic template engine + moderation
  - `WorstAdvice/State/AppState.swift`: SwiftData models, repository, tab view models
  - `WorstAdvice/Views/*.swift`: tab screens, advice card, theming, share-card renderer

## Build & Run
1. Open `/Users/austinbeatty/Downloads/untitled folder/WorstAdvice/WorstAdvice.xcodeproj` in Xcode.
2. Select the `WorstAdvice` scheme.
3. Run on simulator (for example iPhone 17).

CLI build:
```bash
xcodebuild build \
  -project "WorstAdvice.xcodeproj" \
  -scheme "WorstAdvice" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Test
```bash
xcodebuild test \
  -project "WorstAdvice.xcodeproj" \
  -scheme "WorstAdvice" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## QA Checklist
- Generate tab:
  - Generate creates instant advice with selected category + tone.
  - Situation prompt influences output when safe.
  - Suggestion chips fill the prompt quickly.
  - Reroll replaces current advice.
  - Surprise Me randomizes category + tone and generates.
  - Daily Drop produces deterministic daily advice.
  - Save toggles favorite state.
  - Copy writes text to clipboard.
  - Share opens share sheet with exported image card.
- Share export:
  - All 3 templates render correctly.
  - Both square/story aspect ratios render correctly.
  - Disclaimer appears only when enabled in settings.
- Favorites tab:
  - List and grid modes both render correctly.
  - Search and category filters narrow results correctly.
  - Detail view opens and can share.
  - Delete and unsave actions work.
- History tab:
  - New generations appear at top.
  - Search and category filters narrow results correctly.
  - Save from history marks items as favorites.
  - History never exceeds 50 items.
- Settings tab:
  - Theme changes app visuals immediately.
  - Reduce Motion and Haptics toggles affect behavior.
  - Include fake rationale toggle affects newly generated advice.
- Safety:
  - Outputs remain satirical and avoid hateful/self-harm/wrongdoing content.
