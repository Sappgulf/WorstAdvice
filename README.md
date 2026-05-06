# Badvice (iOS)

A SwiftUI satire app that generates confidently wrong advice that still sounds plausible.

## Version
- `6.3`

## Features
- Focused main shell with `Advice`, `Friends`, `Chaos Hub`, and `Quotes` in the tab bar
- `More` quick access keeps Saved, History, Explore, Challenges, Settings, and diagnostics reachable without crowding the primary flow
- User-customizable main tab order with Advice pinned first
- Categories (10): Dating, Fitness, Career, Money, Parenting, Tech, Social, Cooking, Travel, Productivity
- Tone modes (9): Corporate Consultant, Alpha Podcast, Wizard, Influencer, Toxic Best Friend, Boomer, Crypto Bro, Minimalist Monk, Friend Roast
- Themes (6): Warm, Dark, Neon, Sepia, Evergreen, Sunrise
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
  - Quote suggestion queue for user-submitted bad quotes
  - Per-quote local vote state (`like` / `dislike`)
  - Optional community-only generation mode backed by local suggestions
  - Persisted settings
- Share-first workflow:
  - One-tap copy/share
  - Dynamic primary CTA on Advice tab (`Advise Me` rotates to fresh prompts every few generations)
  - `Surprise Me` and deterministic `Daily Drop` quick generation actions
  - Image card export with 3 templates, subtle noise, rounded card, watermark
  - Supports square and story aspect ratios
  - Optional footer disclaimer: `For entertainment only`
- Quotes:
  - Deterministic `Bad Quote of the Day` shared across all users each calendar day
  - Dedicated `Quotes` tab with searchable/filterable quote library
  - Ranking modes: `Recent`, `Top Liked`, `Top Disliked`
  - Expanded built-in quote bank for broader daily rotation and fewer repeats
  - Per-quote like/dislike + copy/share actions with analytics hooks
  - Quote Suggestion Lab for community quote submissions (moderated)
- App Shortcuts:
  - Open Badvice directly to useful destinations
  - Generate bad advice with optional category, tone, friend, and scenario inputs
  - Open today's quote ritual in Quotes
  - Return today's quote inline without opening the app
- Homescreen:
  - WidgetKit extension (`WorstAdviceWidget`) with a daily bad quote card (small/medium)
- Viral loops:
  - Share caption presets (`Deadpan`, `Chaotic`, `Faux Expert`)
  - Streak challenge progress (3/7/14/30-day goals)
  - Friend Roast flow with friend-name targeting
  - Lightweight analytics event logging hooks for key actions
  - Local voting feedback on generated advice (`like` / `dislike`)
  - Suggestion Lab for user-submitted bad advice ideas
  - Community Pulse leaderboard for top suggested topics and top liked/disliked lines
- Social layer (CloudKit-backed):
  - Profile creation with validated handles
  - Friends discovery, request/accept/decline/block flows
  - Friends feed sharing (advice + quotes)
  - Chaos leaderboard submissions
  - Collaboration document drafts/edits
  - Moderation report submission pipeline
  - Offline retry queue for social writes (friend request/share/score/report)
  - Settings diagnostics for social backend + queue health
- Discovery workflows:
  - Favorites supports list/grid plus search and category filters
  - History supports search, category filters, and ranking modes (`Recent`, `Top Liked`, `Top Disliked`)
- Accessibility/perf:
  - Warm/Sepia themes use paper-like textured backgrounds and soft contrast for long sessions
  - Neon contrast tuned with darker cards/text pairing for better readability
  - Dynamic Type-friendly layout
  - VoiceOver labels for key controls
  - Large tap targets and high-contrast theme tokens
  - Instant local generation and rendering

## Architecture
- UI: SwiftUI
- Pattern: MVVM
- Persistence: SwiftData (`AdviceRecord`, `AdviceFingerprint`, `UserAdviceSuggestion`, `UserQuoteSuggestion`, `QuoteVoteRecord`, `LearningStatRecord`, `MissionProgressRecord`, `AppSettingsEntity`)
- Core modules:
  - `Badvice/Models/AdviceModels.swift`: enums + shared models
  - `Badvice/Data/AdviceStore.swift`: category/tone rule definitions
  - `Badvice/Engine/AdviceEngine.swift`: deterministic template engine + moderation
  - `Badvice/State/AppState.swift`: SwiftData models, repository, tab view models, daily quote service
  - `Badvice/Views/*.swift`: tab screens, advice card, theming, share-card renderer

## Repository Layout
- Canonical source tree: this repository root (`/Users/austinbeatty/Downloads/WorstAdvice`).
- App source: `Badvice/`
- Widget source: `WorstAdviceWidget/`
- Tests: `WorstAdviceTests/`
- Build/test scripts: `scripts/`
- Do not reintroduce nested repo/submodule copies (for example `WorstAdvice/` as a gitlink).

## Build & Run
1. Open `Badvice.xcodeproj` in Xcode.
2. Select the `Badvice` scheme.
3. Run on simulator.

CLI build:

If simulator names differ on your machine, resolve one dynamically first:
```bash
xcodebuild -showdestinations -project Badvice.xcodeproj -scheme Badvice
```

```bash
xcodebuild build \
  -project "Badvice.xcodeproj" \
  -scheme "Badvice" \
  -destination "platform=iOS Simulator"
```

## Social (CloudKit) Setup
Social features (`Friends`, feed, leaderboard, collaboration) require CloudKit setup in addition to local app build.

1. In Xcode target settings for `Badvice`, confirm:
   - iCloud capability is enabled.
   - Container includes `iCloud.com.worstadvice.app`.
   - `Badvice/Badvice.entitlements` is attached to the app target.
2. Sign into an iCloud account on your test device/simulator host machine.
3. Launch the app once in Development environment to initialize CloudKit record types.
4. In CloudKit Dashboard, verify schema for:
   - `UserProfile`
   - `FriendRequest`
   - `FriendEdge`
   - Queryable fields described in `docs/cloudkit_schema_setup.md`
5. Before TestFlight/App Store builds, deploy the Development schema to Production in CloudKit Dashboard.
6. If handle/friend queries fail with index/queryable errors, follow the checklist in `docs/cloudkit_schema_setup.md`.

### UI Test Mock Social Backend
For deterministic UI tests without iCloud dependencies:

```bash
-ui-testing-social-mock
```

Optional seeded incoming friend requests count:

```bash
-ui-testing-social-seed-incoming 3
```

## Test
```bash
node scripts/check_project_sources.js
```

```bash
bash scripts/ci_xcodebuild_tests.sh
```

## QA Checklist
- Advice tab:
  - Generate creates instant advice with selected category + tone.
  - Primary action flow is one dominant Advice CTA plus compact secondary icon rail.
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
- Settings:
  - Theme picker shows all 6 themes and applies instantly.
  - Neon remains readable across Advice card, chips, and controls.
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
- Quotes tab:
  - Daily quote remains stable throughout the same day.
  - Daily quote changes the next day.
  - Search and category filters narrow quote library results correctly.
  - Sort modes (`Recent`, `Top Liked`, `Top Disliked`) filter as expected.
  - Per-quote like/dislike toggles persist.
  - Per-quote copy/share actions work from the visible row action menu.
- Settings:
  - Theme changes app visuals immediately.
  - Reduce Motion and Haptics toggles affect behavior.
  - Include fake rationale toggle affects newly generated advice.
  - Content pack picker changes generation style immediately.
  - Community-only toggle forces generation to use moderated user suggestions only.
  - Suggestion Lab navigation opens submit/list/delete flow for community suggestions.
  - Community Pulse view shows top suggested topics and local like/dislike leaders.
  - Quote Suggestion Lab navigation opens submit/list/delete flow for community quotes.
  - Share caption style picker affects copied/shared text captions.
  - Strict no-repeat toggle enforces global uniqueness across generated advice lines.
- More keeps Settings and utility surfaces reachable while tab customization reorders the main shell.
- Visual comfort:
  - Warm theme shows soft paper-like background texture and comfortable contrast for extended reading.
- Widget:
  - `Daily Bad Quote` widget appears in widget gallery.
  - Widget quote updates daily and matches app daily quote cycle.
- Safety:
  - Outputs remain satirical and avoid hateful/self-harm/wrongdoing content.
