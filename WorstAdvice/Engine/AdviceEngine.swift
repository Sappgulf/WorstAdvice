import Foundation

// MARK: - AdviceEngine

/// Pure logic: given current state + store, computes the next tier and selects
/// a non-repeating advice entry.  All inputs are explicit so this is trivially testable.
struct AdviceEngine {

    let store: AdviceStore

    // MARK: - Tier calculation

    /// Determine the effective tier for the NEXT ask.
    ///
    /// - Parameters:
    ///   - askCount: total asks this session lifetime (already incremented for this ask)
    ///   - lastAskDate: timestamp of the previous ask (nil if first ever)
    ///   - now: current date (injectable for tests)
    ///   - isMoreLikeThis: when true, skip rapid-tap and cool-off; just return `lockedTier`
    ///   - lockedTier: the tier to return when `isMoreLikeThis` is true
    func effectiveTier(
        askCount: Int,
        lastAskDate: Date?,
        now: Date = Date(),
        isMoreLikeThis: Bool = false,
        lockedTier: AdviceTier? = nil
    ) -> AdviceTier {

        // "More like this" bypasses all escalation logic.
        if isMoreLikeThis, let locked = lockedTier {
            return locked
        }

        // 1. Base tier from ask count
        var tier: AdviceTier
        switch askCount {
        case 1...3:  tier = .tier1
        case 4...6:  tier = .tier2
        case 7...9:  tier = .tier3
        default:     tier = .tier4
        }

        // 2. Cool-off: no asks for >= 30 minutes => drop 1
        if let last = lastAskDate {
            let gap = now.timeIntervalSince(last)
            if gap >= 30 * 60 {
                tier = tier.cooled()
            }
        }

        // 3. Rapid tap: ask within 10 seconds => bump 1
        if let last = lastAskDate {
            let gap = now.timeIntervalSince(last)
            if gap < 10 && gap >= 0 {
                tier = tier.bumped()
            }
        }

        // 4. Late night bump (23:00–03:59 local)
        if Self.isLateNight(now) {
            tier = tier.bumped()
        }

        return tier
    }

    // MARK: - Late night check

    static func isLateNight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 23 || hour < 4
    }

    // MARK: - Entry selection with anti-repetition

    /// Pick a random entry from `tier` that is not in `recentIDs`.
    /// If the tier pool minus recentIDs is empty, relax to last-3 window.
    /// Returns nil only if the tier is completely empty in the store (should not happen).
    func pickEntry(
        tier: AdviceTier,
        recentIDs: [String]
    ) -> AdviceEntry? {
        pickEntry(tier: tier, category: nil, recentIDs: recentIDs)
    }

    func pickEntry(
        tier: AdviceTier,
        category: AdviceCategory?,
        recentIDs: [String]
    ) -> AdviceEntry? {

        let scopedPool = store.entries(for: tier, category: category)
        let pool = scopedPool.isEmpty ? store.entries(for: tier) : scopedPool
        guard !pool.isEmpty else { return nil }

        // Primary filter: exclude last 8
        let last8 = Set(recentIDs.suffix(8))
        let candidates = pool.filter { !last8.contains($0.id) }

        if let pick = candidates.randomElement() {
            return pick
        }

        // Relaxed filter: exclude last 3 only
        let last3 = Set(recentIDs.suffix(3))
        let relaxed = pool.filter { !last3.contains($0.id) }

        if let pick = relaxed.randomElement() {
            return pick
        }

        // Absolute fallback: anything in the tier
        return pool.randomElement()
    }
}
