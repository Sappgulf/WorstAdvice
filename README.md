# The Worst Advice (iOS)

A SwiftUI satire app that generates confidently wrong advice that still sounds plausible.

## Version
- `1.0.0`

## Features
- Four-tab app: `Generate`, `Favorites`, `History`, `Settings`
- Categories (10): Dating, Fitness, Career, Money, Parenting, Tech, Social, Cooking, Travel, Productivity
- Tone modes (9): Corporate Consultant, Alpha Podcast, Wizard, Influencer, Toxic Best Friend, Boomer, Crypto Bro, Minimalist Monk, Friend Roast
- Rule-based advice engine:
  - Category rules define bad principles, keywords, forbidden patterns, and templates
  - Content packs (`Classic`, `Office Meltdown`, `Weekend Chaos`, `Chronically Online`) expand phrase banks without changing app flow
  - Tone profiles define phrasing/rhetorical style
  - Multi-shape output composition increases variety while staying plausibly wrong
  - Output includes advice line plus optional fake rationale line
  - Optional user situation prompt is woven into output when safe
- Safety layer blocks hateful, self-harm, and wrongdoing-oriented outputs
- SwiftData persistence:
  - Favorites storage
  - History capped to last 50 generated items
  - Persistent no-repeat advice fingerprint memory
  - Category+tone no-repeat fingerprint pools for stricter repeat blocking
  - Per-advice local vote state (`like` / `dislike`)
  - User suggestion queue for recommended advice lines by topic/category
  - Optional community-only generation mode backed by local suggestions
  - Persisted settings
- Share-first workflow:
  - One-tap copy/share
  - `Surprise Me` and deterministic `Daily Drop` quick generation actions
  - Image card export with 3 templates, subtle noise, rounded card, watermark
  - Supports square and story aspect ratios
  - Optional footer disclaimer: `For entertainment only`
- Viral loops:
  - Share caption presets (`Deadpan`, `Chaotic`, `Faux Expert`)
  - Streak challenge progress (3/7/14/30-day goals)
  - Friend Roast flow with friend-name targeting
  - Lightweight analytics event logging hooks for key actions
  - Local voting feedback on generated advice (`like` / `dislike`)
  - Suggestion Lab for user-submitted bad advice ideas
  - Community Pulse leaderboard for top suggested topics and top liked/disliked lines
- Discovery workflows:
  - Favorites supports list/grid plus search and category filters
  - History supports search, category filters, and ranking modes (`Recent`, `Top Liked`, `Top Disliked`)
- Accessibility/perf:
  - Dynamic Type-friendly layout
  - VoiceOver labels for key controls
  - Large tap targets and high-contrast theme tokens
  - Instant local generation and rendering

## Architecture
- UI: SwiftUI
- Pattern: MVVM
- Persistence: SwiftData (`AdviceRecord`, `AdviceFingerprint`, `UserAdviceSuggestion`, `AppSettingsEntity`)
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
  - Primary action flow is one dominant Generate CTA plus compact secondary icon rail.
  - Situation prompt influences output when safe.
  - Friend Roast mode uses optional friend name.
  - Suggestion chips fill the prompt quickly.
  - Surprise Me randomizes category + tone and generates.
  - Daily Drop produces deterministic daily advice.
  - Challenge card updates streak goals and progress.
  - No-repeat status reflects growing unique output count.
  - Like/Dislike vote toggles persist for each generated advice card.
  - Save toggles favorite state.
  - Copy writes text to clipboard.
  - Share opens share sheet with exported image card.
  - If community-only mode is enabled without suggestions, generation shows a clear notice.
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
  - Ranking modes show expected results for Recent, Top Liked, and Top Disliked.
  - Search and category filters narrow results correctly.
  - Save from history marks items as favorites.
  - History never exceeds 50 items.
- Settings tab:
  - Theme changes app visuals immediately.
  - Reduce Motion and Haptics toggles affect behavior.
  - Include fake rationale toggle affects newly generated advice.
  - Content pack picker changes generation style immediately.
  - Community-only toggle forces generation to use moderated user suggestions only.
  - Suggestion Lab navigation opens submit/list/delete flow for community suggestions.
  - Community Pulse view shows top suggested topics and local like/dislike leaders.
  - Share caption style picker affects copied/shared text captions.
  - Strict no-repeat toggle enforces global uniqueness across generated advice lines.
- Safety:
  - Outputs remain satirical and avoid hateful/self-harm/wrongdoing content.
