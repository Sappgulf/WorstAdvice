## [feat] Achievements system  (2026-02-20)

**What:** Full achievements system with 18 achievement types, celebration overlay,
and progress grid UI.

**Achievement types:**
- Generation milestones: First Mistake, Serial Offender (10), Chaos Connoisseur (100)
- Save milestones: Bookmarked Badness (1), Curator of Catastrophe (10), Advice Archivist (50)
- Share milestones: Spread the Badness (5), Going Viral (25)
- Streak milestones: 3-Day Bender, Weekly Chaos, Two Weeks of Trouble, Monthly Madness
- Explorer: Voice Actor (all 11 tones), Jack of All Trades (all 10 categories)
- Secret: Midnight Badvice (advice after midnight), Early Bird Gets the Burn (before 6 AM)
- Special: Shake It Off (shake-to-generate), Community Contributor (submit suggestion)
- Placeholder: Bug Hunter (future Easter egg, unlocks Cybernetic theme)

**Theme unlocks via achievements:**
- 7-day streak → Neon Nights
- 100 generations → Midnight Oil
- All categories → Golden Hour
- Bug Hunter → Cybernetic

**UI:**
- AchievementsView: circular progress ring, filter picker (All / Unlocked / Locked), LazyVGrid
- AchievementCard: icon, title, description (hidden if secret+locked), progress bar or checkmark
- AchievementCelebrationView: spring-animated modal overlay with rotating trophy ring

**Files:**
- `Views/AchievementsView.swift` — AchievementsManager, AchievementsView, AchievementCard, AchievementCelebrationView
- `Models/AdviceModels.swift` — AchievementType, Achievement
