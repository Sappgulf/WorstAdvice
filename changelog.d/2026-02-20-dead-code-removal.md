## [chore] Dead code & duplicate file removal  (2026-02-20)

**What:** Removed unused code and stray duplicate files identified during audit.

**Removed:**
1. `UnlockableTheme` enum (`AdviceModels.swift`) — 40-line enum fully superseded by
   `AchievementType.unlocksTheme`. No callers; the `AchievementsManager.unlockedThemes`
   property already provides the correct unlock-aware theme list from `ThemeMode` directly.

2. `Badvice/SharedDailyQuoteSource.swift` (root-level) — 135-line file that was a
   stray duplicate of `Badvice/Shared/SharedDailyQuoteSource.swift`. The root copy
   was NOT referenced in the Xcode project (pbxproj only references `Shared/` path)
   and was never compiled. Safe to delete from filesystem.

**Kept (intentionally):**
- `DeviceCapabilityProfile.forceLowPowerVisuals` — has identical implementation to
  `prefersReducedEffects` today but serves a distinct semantic role (used separately
  in ContentView for visual-effect gating vs. motion gating).
- `bugHunter` achievement — present in model and `targetFor` switch (returns 1),
  intentional placeholder with `.cybernetic` theme unlock. No tracker function yet;
  intended as a future Easter egg.
- Stub files (`ContentView.swift`, `WorstAdvice.swift`, `WorstAdviceTests.swift`)
  at project root — minimal 3-line comment files in the Xcode build target; harmless.

**Files:**
- `Models/AdviceModels.swift` — removed UnlockableTheme
- deleted: `Badvice/SharedDailyQuoteSource.swift` (filesystem only)
