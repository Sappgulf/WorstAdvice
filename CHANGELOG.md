# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]
### Added
- New `Quotes` tab with searchable/filterable bad-quote library.
- Deterministic `Bad Quote of the Day` service (same quote for everyone each day).
- Daily quote banner on Generate for quick daily humor.
- Dynamic Advice-tab primary CTA text that rotates every few successful generations (for example, `Advise Me`).
- Quote-library voting (`like` / `dislike`) with ranking modes: `Recent`, `Top Liked`, `Top Disliked`.
- Quote Suggestion Lab in Settings for moderated user-submitted quote lines.
- Persistent quote vote and quote suggestion storage (`QuoteVoteRecord`, `UserQuoteSuggestion`).
- User-customizable tab order controls in Settings (Advice pinned first, Settings pinned last).
- New `WorstAdviceWidget` WidgetKit extension for daily bad quote homescreen cards.
- Situation-aware generation: optional user prompt text is safely incorporated into generated advice.
- New Generate controls: `Surprise Me` (random category + tone) and deterministic `Daily Drop`.
- Generate metrics strip for Today/Total/Saved counts.
- Context suggestion chips based on selected category keywords.
- Favorites search + category filter controls.
- History search + category filter controls.
- Additional engine tests for safe situation injection behavior.
- New `Friend Roast` tone mode with optional friend-name personalization.
- Share caption presets for viral posting styles: Deadpan, Chaotic, Faux Expert.
- Streak challenge UI with 3/7/14/30 day progression targets.
- Analytics-ready event tracker for generation, sharing, copy, favorites, and history actions.
- Persistent advice fingerprint memory with strict no-repeat generation mode.
- Settings control for strict no-repeat enforcement.
- Content pack system with selectable modes: `Classic`, `Office Meltdown`, `Weekend Chaos`, `Chronically Online`.
- Engine tests for content-pack determinism and output differentiation.
- Advice voting system (`like` / `dislike`) persisted per generated record.
- Suggestion Lab for user-submitted advice recommendations (category + topic + line) with moderation.
- Persistence tests covering vote storage and suggestion create/delete lifecycle.
- Community-only generation mode toggle in Settings to source advice strictly from moderated user suggestions.
- Dedicated Settings navigation route for Suggestion Lab with submit/list/delete workflow.
- History ranking modes: `Recent`, `Top Liked`, and `Top Disliked`.
- Persistence tests for community-only setting and history vote-ranking filters.
- Community Pulse leaderboard in Settings (top suggested topics + top liked/disliked advice).
- Persistence test for category+tone fingerprint no-repeat pools.
- Persistence tests for quote vote persistence, quote suggestion lifecycle, and tab-order persistence.

### Changed
- Quote-library row actions moved to a visible per-row menu (`Copy`/`Share`) for clearer, less crowded interaction.
- Tab label renamed from `Generate` to `Advice`.
- Generate header copy simplified by removing the explanatory subtitle and using the shorter title `Worst Advice`.
- Default tab order is now `Advice`, `Quotes`, `Favorites`, `History`, `Settings`.
- Warm theme visual polish: paper-like textured background, softer warm palette, and calmer tab bar surface for long-read comfort.
- Theme system expanded with `Sepia`, `Evergreen`, and `Sunrise` options, and Settings now uses a scalable menu picker for theme selection.
- Neon readability improved with higher-contrast background/card/text token tuning.
- Generation now avoids near-term repeated advice lines by retrying with alternate seeds.
- Generator now uses multiple composition shapes and category-specific spice lines to expand safe content variety.
- Category rule banks expanded (keywords, action templates, rationale templates) and generator phrase pools widened for more unique satirical outputs.
- Quote library expanded with 20 additional built-in bad quotes across all categories.
- Moderation term list expanded for stronger self-harm and wrongdoing blocking.
- Simplified tab UX for clarity and density: compact Generate controls, collapsed advanced tools, menu-based list filters, and calmer non-neon backgrounds.
- Removed duplicate generation action (`Reroll`) and kept a single primary `Generate` flow.
- Removed duplicate share-style controls from Generate (settings is now the single source of truth).
- Generate tab action hierarchy tightened: clearer top guidance, denser primary actions, and explicit rate-this-advice controls.
- Generation can source from moderated user suggestions for matching categories/topics while preserving no-repeat checks.
- Generate tab decluttered by removing in-tab Suggestion Lab controls in favor of Settings-based entry.
- Generate actions flattened to one dominant `Generate` CTA with a compact secondary icon rail.
- Strict no-repeat now enforces both global fingerprints and category+tone fingerprint pools.
- Reduced repeated quote-tab persistence fetches by caching quote suggestions and vote maps in `QuotesViewModel` and refreshing only on mutation.

### Fixed
- Hardened GitHub Actions simulator destination resolution to handle Xcode output format changes and fallback to `simctl`-listed iPhone devices.

## [1.0.0] - 2026-02-13
### Added
- New SwiftUI MVVM app shell with tabs: Generate, Favorites, History, Settings.
- Rule-based satire advice engine using category rules + tone profiles.
- Categories: Dating, Fitness, Career, Money, Parenting, Tech, Social, Cooking, Travel, Productivity.
- Tone modes: Corporate Consultant, Alpha Podcast, Wizard, Influencer, Toxic Best Friend, Boomer, Crypto Bro, Minimalist Monk.
- Optional fake rationale output line for generated advice.
- Lightweight moderation filter to block hateful, self-harm, and wrongdoing-oriented outputs.
- SwiftData local persistence for advice history, favorites, and settings.
- History retention cap of 50 items.
- Share-card image export (UIKit renderer) with:
  - 3 visual templates
  - gradient backgrounds
  - rounded card style
  - subtle noise texture
  - watermark
  - story + square aspect ratios
  - optional disclaimer footer.
- Unit tests for deterministic generation, constraints, moderation, and persistence.
- README QA checklist and architecture notes.

### Changed
- Reworked UI styling to a warm, cozy default visual direction.
- Updated interactions for one-tap Generate, Reroll, Save, Share, and Copy flows.
- Updated project marketing version to `1.0.0`.

### Fixed
- Removed moderation fallback wording that could retrigger safety filters.
