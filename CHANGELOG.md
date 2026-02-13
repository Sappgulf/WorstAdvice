# Changelog

All notable changes to this project are documented in this file.

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
