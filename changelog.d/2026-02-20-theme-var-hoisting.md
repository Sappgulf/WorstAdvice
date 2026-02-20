## [perf] Theme var hoisting — all view structs  (2026-02-20)

**What:** Replaced all inline `Theme.X(for: settings.theme)` / `Theme.X(for: theme)` calls
in every view struct with hoisted computed properties:
```swift
private var accent: Color       { Theme.accent(for: settings.theme) }
private var primaryText: Color  { Theme.primaryText(for: settings.theme) }
private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
private var cardColor: Color    { Theme.cardColor(for: settings.theme) }
private var buttonText: Color   { Theme.buttonText(for: settings.theme) }
```

**Why:** SwiftUI re-evaluates `body` on every state change. Each inline `Theme.X(for:)`
call performs a switch statement lookup. Hoisting moves those lookups to computed
properties accessed once per body evaluation, reducing repeated work per frame.

**Files:**
- `Views/AchievementsView.swift` — AchievementsView, AchievementCard
- `Views/ChaosHubView.swift` — ChaosHubTabView
- `Views/GenerateTabView.swift` — GenerateTabView
- `Views/StatsView.swift` — FavoritesTabView, QuotesTabView, FavoriteDetailView, HistoryTabView
- `Views/InterstitialMessages.swift` — SettingsTabView, SuggestionLabView, QuoteSuggestionLabView, CommunityPulseView
- `Views/OnboardingView.swift` — OnboardingHistoryView
