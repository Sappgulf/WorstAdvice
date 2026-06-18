# Badvice Upgrade Backlog

## Now
- Verify the new `GenerateTabView` command card, Missions progression path, Friends setup funnel, and Quotes daily ritual in browser-visible simulator proof.
- Refresh App Store screenshots around the current primary surfaces: Generate, Missions, Quotes, Friends, Saved, and Settings using the scripted device matrix.
- Use screenshot mode for deterministic browser proof and App Store capture prep.
- Run `scripts/capture_screenshot_mode.sh` after UI smoke is green to refresh repeatable tab screenshots.
- Keep empty/loading states action-led as each surface evolves.

## Next
- Continue tightening progression rewards, social first-use, quote sharing, and upgrade entitlement clarity after the browser/test pass.
- Review the scripted App Store screenshot matrix and select final App Store Connect images.
- Consider a small generated bitmap texture/background only if it materially improves share-card or onboarding art without adding asset noise.

## Later
- Add seasonal content loops, limited-time missions, and better reward surfaces.
- Finish Live Activities and widget tie-ins for streaks, daily quote, and daily mission progress.
- Add richer social loops: challenges, collab threads, vote-driven prompts, recap cards.
- Ship more personalized identity surfaces such as chaos archetype, weekly recap, and profile badges.

## Technical Cleanup
- Break down oversized views in `GenerateTabView`, `ContentView`, and `FriendsTabView`.
- Push more repeated section-shell styling into shared view helpers.
- Audit unfinished/stubbed systems and either complete or hide them.
- Expand targeted test coverage around Generate flow, social setup flow, and progression state.
