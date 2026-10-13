# Badvice redesign and engineering audit

Audit started October 12, 2026. Direction: Mischief magazine — warm paper, editorial type, red ink, playful stamps.

## Acceptance criteria

- Guest entry and protected local accounts both work and retain separate histories.
- Advice has one clear primary action, working topic/voice/context controls, saving, sharing and rewrites.
- Apple Foundation Models is the preferred generator; actual source and fallback state are visible.
- Every topic and voice reaches the Apple request contract, including intensity and rewrite direction.
- Saved, Play, Daily and Party form complete flows with honest empty and error states.
- Party voting validates players, disallows self-votes, persists progress and reports ties.
- CloudKit identity, optional fetches, retry ownership and diagnostics preserve data integrity.
- Build, configuration checks, unit tests and simulator workflows have recorded evidence.

## Changes

The default palette and components use cream paper, ink, red accents and opaque surfaces. The Advice screen now has a magazine masthead, compact composer, one dominant action and optional tuning/rewrite tools. Splash and onboarding are shorter, cancellation-aware and respect reduced motion. Navigation uses Advice, Saved, Play, Daily and Party consistently.

Guest sessions have a stable separate account identity. Foregrounding no longer rebuilds the session. Daily notification scheduling respects opt-out. Saved records still use local SwiftData; this is not cross-device sync.

Demo group challenges, invented invite codes and fabricated feed activity were removed. Party is a real local pass-the-phone game; the social feed displays backend records. Settings now exposes profile creation, handle search, incoming requests, friends, explicit public publishing and the feed. Simulator social mocks require a testing launch; signed simulator builds use CloudKit. Unsigned builds report an explicit unavailable state and reject every social write.

Foundation Models now uses a `@Generable` response, direct system readiness checks and one request for every topic, voice, situation, intensity and rewrite. A successful Apple request cannot silently lose to a community candidate. Source labels identify Apple Intelligence or the local Bureau fallback. Legacy defaults migrate once; later engine choices persist. The model's generated explanation is used for the reality check. Apple's guardrails remain enabled and refusals fall back honestly.

The first live prompt was rejected by Apple's guardrails. The old category instructions included unsafe behavior and conflicted with their own restrictions. They were replaced with harmless fictional comedy settings. Friend Roast's optional name field previously blocked generation; that mismatch was fixed. Old manual JSON parsing and an unused model summarization path were removed.

CloudKit fixes distinguish missing records from transient errors, validate profile ownership against the current iCloud user, react to account changes, scope queues to local accounts, bind queued writes to their original profile and give post retries stable IDs. Refresh generations prevent stale responses from repainting a new account. Diagnostics preserve fresh errors.

Privacy declarations now reflect optional profile identifiers, display names and shared user content. CI and screenshot scripts share incremental build caches, use the selected Xcode, accept explicit simulator IDs and preserve result bundles. A configuration check verifies container and entitlement consistency. Shutdown, unused simulators were deleted with user authorization after an initial build failed for lack of disk space.

## Evidence

Evidence logs and simulator screenshots are in ignored `.build/polish-evidence/`. Baseline: 158 unit tests passed. First redesign pass: 166 unit tests and core navigation/party UI flows passed. Later focused unit pass: 171 passed. Subsequent model tests exposed the Friend Roast and guardrail defects above; those failure logs are preserved. The final unit run (`checked-unit.xcresult`) passed all 177 tests. Its live app-generator sweep attempted all 16 topics and all 16 voices: 14 Apple results and two explained local fallbacks. The full 256-pair injected routing matrix and 1,445 topic/voice/intensity request checks passed. The Finance/Crypto + LinkedIn pair produced a typed Apple refusal; guardrails stayed enabled and the app labeled the Bureau fallback honestly.

UI tests for retired demo flows were replaced with strict tests for current workflows. They cover account entry, onboarding, saved organization, foreground restoration, customization, sharing, suggestions, party persistence, diagnostic states, actual model source and explicit mock social interactions. Builds alone do not count as visual verification.

## Final UI evidence

All 20 current UI workflows were verified across the compact iPhone SE and regular iPhone simulators running iOS 27. The full compact sweep passed 17; quote submission passed `compact-details`, and the final rewrite/advice-submission pair passed `gesture-compact-ui` (2 tests, zero failures). The corresponding regular-phone rerun passed `details-ui` (3 tests, zero failures). These are combined focused results, not a claim that the earlier whole-suite runs were clean.

Default XCTest swipe coordinates were reaching the floating navigation on the compact screen. Tests now gesture within visible content and bring a horizontal row into view before swiping it. Failed or interrupted test launches are retained in their own logs. The clean unit bundle is `checked-unit.xcresult`; some interrupted UI bundles lack finalized metadata, so their observed logs are the evidence.

The `badvice://quotes` route was exercised through the simulator's Open URL confirmation and visibly opened Daily. Current captures: `final-advice.png`, `final-apple.png`, and `final-daily.png` in `.build/polish-evidence/`. The Apple capture shows an actual structured on-device result and its source label.

## External release work

The signed-in CloudKit Dashboard was inspected read-only in Development on October 13. Four record types are missing, and `UserProfile.ownerUserRecordName` lacks its query index; the `_world`, `_icloud`, and `_creator` roles are recorded in `cloudkit_schema_setup.md`. The local CLI still has no management token, so Production was not inspected or changed. The signed two-user checks remain required. The current public-database design needs secured participant authorization for sender-owned friend-request responses and collaboration edits, plus atomic handle uniqueness. Broad authenticated Write permissions would expose other users' records and are not a valid fix. See `cloudkit_schema_setup.md` for the concrete release checks.

The public friends filter is discovery behavior, not server-enforced privacy. Publishing now explains that boundary explicitly. Local accounts, saved advice and party state remain local to the device.

Additional simulator fixes include full-row touch targets for expansions, keyboard Done controls, separate focus targets for situation/friend-name input, form spacing above the floating footer, and test scrolling that follows vertical and horizontal containers. Temporary social refresh states preserve the saved profile link. The app now explicitly registers its widget URL scheme and carries signing status in its generated Info.plist.

Apple model availability and output vary by device, region, enabled Apple Intelligence, downloaded assets and request safety. Matrix routing tests prove app contracts; live framework tests and screenshots prove observed model execution separately.
