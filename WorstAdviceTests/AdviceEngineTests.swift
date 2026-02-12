import XCTest
@testable import WorstAdvice

final class AdviceEngineTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a store with known entries: 4 per tier, IDs like "test_t1_0" etc.
    private func makeTestStore() -> AdviceStore {
        var entries: [AdviceEntry] = []
        for tier in AdviceTier.allCases {
            for i in 0..<4 {
                entries.append(AdviceEntry(
                    id: "test_t\(tier.rawValue)_\(i)",
                    tier: tier,
                    category: .daily,
                    text: "Tier \(tier.rawValue) entry \(i)"
                ))
            }
        }
        return AdviceStore(entries: entries)
    }

    private func makeEngine() -> AdviceEngine {
        AdviceEngine(store: makeTestStore())
    }

    /// Create a Date at a specific hour today.
    private func today(hour: Int, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)!
    }

    // MARK: - Tier escalation boundaries

    func testBaseTierFromAskCount() {
        let engine = makeEngine()
        let noon = today(hour: 12)
        // 60 seconds ago: outside rapid-tap window (10s) and inside cool-off window (30min)
        let recent = noon.addingTimeInterval(-60)

        // Asks 1-3 => Tier 1
        XCTAssertEqual(engine.effectiveTier(askCount: 1, lastAskDate: recent, now: noon), .tier1)
        XCTAssertEqual(engine.effectiveTier(askCount: 3, lastAskDate: recent, now: noon), .tier1)

        // Asks 4-6 => Tier 2
        XCTAssertEqual(engine.effectiveTier(askCount: 4, lastAskDate: recent, now: noon), .tier2)
        XCTAssertEqual(engine.effectiveTier(askCount: 6, lastAskDate: recent, now: noon), .tier2)

        // Asks 7-9 => Tier 3
        XCTAssertEqual(engine.effectiveTier(askCount: 7, lastAskDate: recent, now: noon), .tier3)
        XCTAssertEqual(engine.effectiveTier(askCount: 9, lastAskDate: recent, now: noon), .tier3)

        // Asks 10+ => Tier 4
        XCTAssertEqual(engine.effectiveTier(askCount: 10, lastAskDate: recent, now: noon), .tier4)
        XCTAssertEqual(engine.effectiveTier(askCount: 50, lastAskDate: recent, now: noon), .tier4)
    }

    // MARK: - Late-night bump

    func testLateNightBump() {
        let engine = makeEngine()
        let midnight = today(hour: 0)
        let elevenPM = today(hour: 23)
        let threeAM = today(hour: 3)
        let longAgo = midnight.addingTimeInterval(-7200)

        // Ask 1 is normally Tier 1; at midnight it should bump to Tier 2
        XCTAssertEqual(engine.effectiveTier(askCount: 1, lastAskDate: longAgo, now: midnight), .tier2)
        XCTAssertEqual(engine.effectiveTier(askCount: 1, lastAskDate: longAgo, now: elevenPM), .tier2)
        XCTAssertEqual(engine.effectiveTier(askCount: 1, lastAskDate: longAgo, now: threeAM), .tier2)

        // 4 AM is NOT late night
        let fourAM = today(hour: 4)
        XCTAssertEqual(engine.effectiveTier(askCount: 1, lastAskDate: longAgo, now: fourAM), .tier1)
    }

    func testLateNightCapsAtTier4() {
        let engine = makeEngine()
        let midnight = today(hour: 0)
        let longAgo = midnight.addingTimeInterval(-7200)

        // Ask 10 is base Tier 4; late night bump should still be Tier 4 (not crash)
        XCTAssertEqual(engine.effectiveTier(askCount: 10, lastAskDate: longAgo, now: midnight), .tier4)
    }

    // MARK: - Cool-off

    func testCoolOff30MinutesDropsTier() {
        let engine = makeEngine()
        let noon = today(hour: 12)
        let thirtyOneMinutesAgo = noon.addingTimeInterval(-31 * 60)

        // Ask 4 is normally Tier 2; with 31-min gap it should cool to Tier 1
        XCTAssertEqual(engine.effectiveTier(askCount: 4, lastAskDate: thirtyOneMinutesAgo, now: noon), .tier1)
    }

    func testCoolOffDoesNotGoBelow1() {
        let engine = makeEngine()
        let noon = today(hour: 12)
        let hourAgo = noon.addingTimeInterval(-3600)

        // Ask 1 is Tier 1; cool-off should not drop below Tier 1
        XCTAssertEqual(engine.effectiveTier(askCount: 1, lastAskDate: hourAgo, now: noon), .tier1)
    }

    // MARK: - Rapid tap

    func testRapidTapBumpsTier() {
        let engine = makeEngine()
        let noon = today(hour: 12)
        let fiveSecondsAgo = noon.addingTimeInterval(-5)

        // Ask 1 is Tier 1; rapid tap should bump to Tier 2
        XCTAssertEqual(engine.effectiveTier(askCount: 1, lastAskDate: fiveSecondsAgo, now: noon), .tier2)
    }

    func testRapidTapCapsAtTier4() {
        let engine = makeEngine()
        let noon = today(hour: 12)
        let twoSecondsAgo = noon.addingTimeInterval(-2)

        // Ask 10 is Tier 4; rapid tap should stay Tier 4
        XCTAssertEqual(engine.effectiveTier(askCount: 10, lastAskDate: twoSecondsAgo, now: noon), .tier4)
    }

    // MARK: - "More like this" bypasses escalation

    func testMoreLikeThisLocksToTier() {
        let engine = makeEngine()
        let noon = today(hour: 12)

        let result = engine.effectiveTier(
            askCount: 50,
            lastAskDate: noon.addingTimeInterval(-1),
            now: noon,
            isMoreLikeThis: true,
            lockedTier: .tier2
        )
        XCTAssertEqual(result, .tier2)
    }

    // MARK: - Non-repetition

    func testPickEntryAvoidsRecentIDs() {
        let engine = makeEngine()
        let tier1IDs = ["test_t1_0", "test_t1_1", "test_t1_2"]

        // With 3 of 4 tier-1 entries blocked, the remaining one must be picked.
        for _ in 0..<20 {
            let pick = engine.pickEntry(tier: .tier1, recentIDs: tier1IDs)
            XCTAssertNotNil(pick)
            XCTAssertEqual(pick?.id, "test_t1_3")
        }
    }

    func testPickEntryRelaxesWhenExhausted() {
        let engine = makeEngine()
        // Block all 4 tier-1 entries in recent-8 window
        let allTier1 = ["test_t1_0", "test_t1_1", "test_t1_2", "test_t1_3"]

        // Should relax to last-3 window, which means only the last 3 are blocked
        // (index 1,2,3). Entry 0 should be available.
        for _ in 0..<20 {
            let pick = engine.pickEntry(tier: .tier1, recentIDs: allTier1)
            XCTAssertNotNil(pick)
            XCTAssertEqual(pick?.id, "test_t1_0")
        }
    }

    func testPickEntryFallsBackCompletely() {
        // If even the relaxed window blocks everything, any entry can be returned.
        let engine = makeEngine()
        // recent = last 3 of these 4, plus the first. But recency window for
        // relaxed is suffix(3) so ids 1,2,3. id 0 escapes in relaxed.
        // To truly exhaust: we need all 4 in last 3 positions, which is impossible
        // with distinct IDs.  So this fallback is hard to trigger with 4 entries.
        // Just verify we always get something back.
        let pick = engine.pickEntry(
            tier: .tier1,
            recentIDs: ["test_t1_0", "test_t1_1", "test_t1_2", "test_t1_3"]
        )
        XCTAssertNotNil(pick)
    }

    func testStoreTierLookupReturnsExpectedCount() {
        let store = makeTestStore()
        XCTAssertEqual(store.entries(for: .tier1).count, 4)
        XCTAssertEqual(store.entries(for: .tier2).count, 4)
        XCTAssertEqual(store.entries(for: .tier3).count, 4)
        XCTAssertEqual(store.entries(for: .tier4).count, 4)
    }

    func testStoreCategoryLookupReturnsScopedEntries() {
        let store = makeTestStore()
        XCTAssertEqual(store.entries(for: .tier1, category: .daily).count, 4)
        XCTAssertEqual(store.entries(for: .tier1, category: .work).count, 0)
    }

    func testPickEntryFallsBackWhenCategoryHasNoEntries() {
        let entries = [
            AdviceEntry(id: "a", tier: .tier1, category: .daily, text: "A"),
            AdviceEntry(id: "b", tier: .tier1, category: .daily, text: "B")
        ]
        let engine = AdviceEngine(store: AdviceStore(entries: entries))
        let pick = engine.pickEntry(tier: .tier1, category: .work, recentIDs: [])
        XCTAssertNotNil(pick)
        XCTAssertTrue(["a", "b"].contains(pick?.id ?? ""))
    }

    // MARK: - Combined modifiers

    func testCoolOffAndLateNightCancel() {
        let engine = makeEngine()
        let midnight = today(hour: 0)
        let hourBefore = midnight.addingTimeInterval(-3600)

        // Ask 4 base = Tier 2
        // Cool-off (1 hr gap): Tier 2 -> Tier 1
        // Late night: Tier 1 -> Tier 2
        // Net: Tier 2
        XCTAssertEqual(engine.effectiveTier(askCount: 4, lastAskDate: hourBefore, now: midnight), .tier2)
    }
}

final class AppStateTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components)!
    }

    func testRegisterGeneratedAdviceUpdatesCountersAndMetadata() {
        let state = AppState(askCount: 2, lastAskDate: nil, lastTier: .tier1, recentIDs: [])
        let now = Date()
        let entry = AdviceEntry(
            id: "state_test_1",
            tier: .tier3,
            category: .work,
            text: "Sample entry"
        )

        state.registerGeneratedAdvice(entry, tier: .tier3, at: now)

        XCTAssertEqual(state.askCount, 3)
        XCTAssertEqual(state.lastTier, .tier3)
        XCTAssertEqual(state.lastAskDate, now)
        XCTAssertEqual(state.currentAdvice, entry)
        XCTAssertEqual(state.totalLifetimeAsks, 1)
        XCTAssertEqual(state.highestTierReached, .tier3)
        XCTAssertEqual(state.categoryHits["work"], 1)
        XCTAssertNotNil(state.firstAskDate)
    }

    func testRegisterMoreLikeThisDoesNotIncrementAskCountOrLastAskDate() {
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let state = AppState(askCount: 5, lastAskDate: oldDate, lastTier: .tier2, recentIDs: [])
        let entry = AdviceEntry(
            id: "state_test_2",
            tier: .tier2,
            category: .social,
            text: "Sample entry"
        )

        state.registerMoreLikeThis(entry, tier: .tier2)

        XCTAssertEqual(state.askCount, 5)
        XCTAssertEqual(state.lastAskDate, oldDate)
        XCTAssertEqual(state.currentAdvice, entry)
        XCTAssertEqual(state.totalLifetimeAsks, 1)
        XCTAssertEqual(state.categoryHits["social"], 1)
    }

    func testRecentIDsAreCappedTo64Entries() {
        let seedIDs = (0..<64).map { "old_\($0)" }
        let state = AppState(askCount: 0, lastAskDate: nil, lastTier: .tier1, recentIDs: seedIDs)
        let entry = AdviceEntry(
            id: "state_test_new",
            tier: .tier1,
            category: .daily,
            text: "Sample entry"
        )

        state.registerMoreLikeThis(entry, tier: .tier1)

        XCTAssertEqual(state.recentIDs.count, 64)
        XCTAssertEqual(state.recentIDs.last, "state_test_new")
        XCTAssertFalse(state.recentIDs.contains("old_0"))
    }

    func testToggleFavoriteAddsAndRemoves() {
        let state = AppState(askCount: 0, lastAskDate: nil, lastTier: .tier1, recentIDs: [])

        state.toggleFavorite(id: "fav_1")
        XCTAssertTrue(state.isFavorite(id: "fav_1"))
        XCTAssertEqual(state.favoriteIDs, ["fav_1"])

        state.toggleFavorite(id: "fav_1")
        XCTAssertFalse(state.isFavorite(id: "fav_1"))
        XCTAssertTrue(state.favoriteIDs.isEmpty)
    }

    func testStreakIncrementsOnConsecutiveDaysAndResetsAfterGap() {
        let state = AppState(askCount: 0, lastAskDate: nil, lastTier: .tier1, recentIDs: [])
        let entry = AdviceEntry(id: "streak", tier: .tier1, category: .daily, text: "S")

        state.registerMoreLikeThis(entry, tier: .tier1, at: date(2026, 2, 10))
        XCTAssertEqual(state.streakCount, 1)

        state.registerMoreLikeThis(entry, tier: .tier1, at: date(2026, 2, 11))
        XCTAssertEqual(state.streakCount, 2)

        // Same day should not increase.
        state.registerMoreLikeThis(entry, tier: .tier1, at: date(2026, 2, 11, hour: 18))
        XCTAssertEqual(state.streakCount, 2)

        // Gap of more than one day should reset.
        state.registerMoreLikeThis(entry, tier: .tier1, at: date(2026, 2, 14))
        XCTAssertEqual(state.streakCount, 1)
    }
}
