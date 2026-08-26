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
- Break down oversized views in `GenerateTabView`, `ContentView`, and `StatsView`.
- Push more repeated section-shell styling into shared view helpers.
- ~~Audit unfinished/stubbed systems and either complete or hide them.~~ Done
  26 Aug 2026: removed the pre-Bureau tab views (Explore/Quotes/ChaosHub/legacy
  Favorites+History), unused `ImageCache`/`AnimatedShareExporter`/`ErrorBoundaryView`/
  `IntensityIndicator`, and 56 speculative model types from `AppModels`/`GamificationModels`.
- Refresh the UI smoke suites against the Bureau shell — a number of them still assert
  pre-rebuild identifiers and copy (see "UI test debt" below).
- Expand targeted test coverage around Generate flow, social setup flow, and progression state.

## UI test debt
The Bureau rebuild renamed most surfaces; the UI suites were not updated with it.
Fixed so far: the History/Casebook assertion, the Generate action-rail header, and the
four settings tests that needed the new `settings.advanced` push. Still stale/failing:
- `tab.chaosHub` / `tab.quotes` "recognizable marker" checks expect `chaos.command.primary`,
  `quotes.spotlight.toggle`, and the old "Favorites"/"Missions"/"Quotes" titles.
- Explore routing tests still expect a standalone Explore surface (it is now the
  Dispatches "Starters" desk).
- The local-auth signup/signout/password flows and the group-challenge copy-code check
  time out; these need investigation rather than a selector swap.
- Cold launch takes ~8s to first paint on a clean install, which is close enough to the
  15s readiness timeouts to make several tests flaky. Worth profiling.
