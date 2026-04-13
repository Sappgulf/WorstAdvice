# Badvice Upgrade Backlog

## Now
- Simplify `GenerateTabView` so the primary path is obvious: controls, prompt, current advice, actions.
- Move secondary content on Generate into progressive disclosure instead of stacking everything on first load.
- Standardize section spacing, card shells, and CTA hierarchy across `Generate`, `Chaos Hub`, `Quotes`, and `Friends`.
- Reduce overlapping motion treatments on `AdviceCardView` and keep one stronger signature interaction.
- Improve empty and loading states so each state explains the next useful action.

## Next
- Rework `ChaosHubView` into the main progression surface: streaks, missions, rewards, season status, next recommended action.
- Simplify `FriendsTabView` into a guided setup funnel: profile, first friend, first share, first collab.
- Make `QuotesTabView` more retention-driven with stronger daily ritual, sharing, and spotlight behavior.
- Clarify premium tiers in `UpgradeStoreView` and connect entitlements from `StoreKitManager` to visible product value.
- Tighten onboarding so it reflects the actual first-use loop and strongest product hooks.

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
